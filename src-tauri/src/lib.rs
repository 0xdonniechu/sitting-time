mod settings;
mod timer;

use settings::{GeneralSettings, SettingsPayload};
use std::{
    path::PathBuf,
    sync::Mutex,
    thread,
    time::Duration,
};
use tauri::{
    menu::{Menu, MenuItem, PredefinedMenuItem},
    tray::TrayIconBuilder,
    AppHandle, Emitter, Manager, WindowEvent,
};
use tauri_plugin_notification::NotificationExt;
use timer::{SessionKind, TimerEngine, TimerMode, TimerSnapshot};

#[derive(Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct ReminderAlert {
    title: &'static str,
    body: &'static str,
    show_fullscreen: bool,
    play_sound: bool,
}

struct AppState {
    timer: Mutex<TimerEngine>,
    general: Mutex<GeneralSettings>,
    config_path: PathBuf,
}

fn show_window(app: &AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.show();
        let _ = window.unminimize();
        let _ = window.set_focus();
    }
}

fn snapshot(app: &AppHandle) -> Option<TimerSnapshot> {
    app.state::<AppState>()
        .timer
        .lock()
        .ok()
        .map(|engine| engine.snapshot())
}

fn persist(app: &AppHandle) -> Result<(), String> {
    let state = app.state::<AppState>();
    let timer = state.timer.lock().map_err(|_| "Timer state is unavailable")?;
    let general = state.general.lock().map_err(|_| "Settings are unavailable")?;
    settings::save(&state.config_path, &timer, &general)
}

fn emit_snapshot(app: &AppHandle) {
    if let Some(current) = snapshot(app) {
        let _ = app.emit("timer-state", current);
    }
}

fn mutate_timer(app: &AppHandle, action: impl FnOnce(&mut TimerEngine)) {
    if let Ok(mut engine) = app.state::<AppState>().timer.lock() {
        action(&mut engine);
    }
    let _ = persist(app);
    emit_snapshot(app);
}

fn notify_session(app: &AppHandle, session: SessionKind) {
    let settings = app.state::<AppState>()
        .general
        .lock()
        .map(|settings| settings.clone())
        .unwrap_or_default();

    let (title, body) = match session {
        SessionKind::Focus => ("Break complete", "Ready for another focus session"),
        SessionKind::ShortBreak => ("Focus session complete", "Take a short break"),
        SessionKind::LongBreak => ("Focus cycle complete", "Take a long break"),
        SessionKind::Sitting => ("Break complete", "You can return to work"),
        SessionKind::Move => ("Time to stand up", "Move around for a few minutes"),
    };

    if settings.notifications_enabled {
        let _ = app.notification().builder().title(title).body(body).show();
    }

    if settings.fullscreen_reminders_enabled || settings.alert_sound_enabled {
        if let Some(window) = app.get_webview_window("reminder") {
            if settings.fullscreen_reminders_enabled {
                let _ = window.show();
                let _ = window.set_focus();
            }
            let _ = window.emit("reminder-alert", ReminderAlert {
                title,
                body,
                show_fullscreen: settings.fullscreen_reminders_enabled,
                play_sound: settings.alert_sound_enabled,
            });
        }
    }
}

#[tauri::command]
fn dismiss_reminder(app: AppHandle) {
    if let Some(window) = app.get_webview_window("reminder") {
        let _ = window.hide();
    }
}

#[tauri::command]
fn preview_reminder(app: AppHandle) {
    notify_session(&app, SessionKind::Move);
}

#[tauri::command]
fn get_timer_state(app: AppHandle) -> Result<TimerSnapshot, String> {
    let transitioned = app.state::<AppState>()
        .timer
        .lock()
        .map(|mut engine| engine.tick())
        .map_err(|_| "Timer state is unavailable".to_string())?;
    let current = snapshot(&app).ok_or_else(|| "Timer state is unavailable".to_string())?;
    if transitioned {
        let _ = persist(&app);
        notify_session(&app, current.session);
    }
    Ok(current)
}

#[tauri::command]
fn start_timer(app: AppHandle) -> Result<TimerSnapshot, String> {
    mutate_timer(&app, TimerEngine::start);
    snapshot(&app).ok_or_else(|| "Timer state is unavailable".to_string())
}

#[tauri::command]
fn pause_timer(app: AppHandle) -> Result<TimerSnapshot, String> {
    mutate_timer(&app, TimerEngine::pause);
    snapshot(&app).ok_or_else(|| "Timer state is unavailable".to_string())
}

#[tauri::command]
fn skip_session(app: AppHandle) -> Result<TimerSnapshot, String> {
    mutate_timer(&app, TimerEngine::skip);
    snapshot(&app).ok_or_else(|| "Timer state is unavailable".to_string())
}

#[tauri::command]
fn reset_session(app: AppHandle) -> Result<TimerSnapshot, String> {
    mutate_timer(&app, TimerEngine::reset_current_session);
    snapshot(&app).ok_or_else(|| "Timer state is unavailable".to_string())
}

#[tauri::command]
fn select_mode(app: AppHandle, mode: TimerMode) -> Result<TimerSnapshot, String> {
    mutate_timer(&app, |engine| engine.set_mode(mode));
    snapshot(&app).ok_or_else(|| "Timer state is unavailable".to_string())
}

#[tauri::command]
fn get_settings(app: AppHandle) -> Result<SettingsPayload, String> {
    let state = app.state::<AppState>();
    let timer = state.timer.lock().map_err(|_| "Timer state is unavailable")?;
    let general = state.general.lock().map_err(|_| "Settings are unavailable")?;
    Ok(settings::payload(&timer, &general))
}

#[tauri::command]
fn save_settings(app: AppHandle, settings: SettingsPayload) -> Result<TimerSnapshot, String> {
    settings.validate()?;
    {
        let state = app.state::<AppState>();
        state.timer
            .lock()
            .map_err(|_| "Timer state is unavailable")?
            .update_settings(settings.timer_settings());
        *state.general.lock().map_err(|_| "Settings are unavailable")? = settings.general_settings();
    }
    persist(&app)?;
    emit_snapshot(&app);
    snapshot(&app).ok_or_else(|| "Timer state is unavailable".to_string())
}

fn start_timer_worker(app: AppHandle) {
    thread::spawn(move || {
        let mut previous: Option<TimerSnapshot> = None;
        loop {
            thread::sleep(Duration::from_millis(200));
            if let Ok(mut engine) = app.state::<AppState>().timer.lock() {
                let transitioned = engine.tick();
                let current = engine.snapshot();
                if previous.as_ref() != Some(&current) {
                    previous = Some(current.clone());
                    drop(engine);
                    if transitioned {
                        let _ = persist(&app);
                        notify_session(&app, current.session);
                    }
                    let _ = app.emit("timer-state", current);
                }
            }
        }
    });
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            Some(vec![]),
        ))
        .invoke_handler(tauri::generate_handler![
            get_timer_state,
            start_timer,
            pause_timer,
            skip_session,
            reset_session,
            select_mode,
            get_settings,
            save_settings,
            dismiss_reminder,
            preview_reminder
        ])
        .setup(|app| {
            let config_dir = app.path().app_config_dir()?;
            let config_path = config_dir.join("state.json");
            let legacy_path = config_dir
                .parent()
                .map(|parent| parent.join("com.donniechu.productivitytray").join("state.json"));
            let restored = if config_path.exists() {
                settings::load(&config_path)
            } else if let Some(path) = legacy_path.filter(|path| path.exists()) {
                settings::load(&path)
            } else {
                settings::PersistedAppState::default()
            };
            let start_minimized = restored.general.start_minimized_to_tray;
            app.manage(AppState {
                timer: Mutex::new(restored.timer),
                general: Mutex::new(restored.general),
                config_path,
            });

            let show = MenuItem::with_id(app, "show", "Show", true, None::<&str>)?;
            let start = MenuItem::with_id(app, "start", "Start / Resume", true, None::<&str>)?;
            let pause = MenuItem::with_id(app, "pause", "Pause", true, None::<&str>)?;
            let stand_up = MenuItem::with_id(app, "stand-up", "Start Stand Up Mode", true, None::<&str>)?;
            let pomodoro = MenuItem::with_id(app, "pomodoro", "Start Pomodoro Mode", true, None::<&str>)?;
            let skip = MenuItem::with_id(app, "skip", "Skip Current Session", true, None::<&str>)?;
            let settings = MenuItem::with_id(app, "settings", "Settings", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;
            let separator = PredefinedMenuItem::separator(app)?;
            let separator_two = PredefinedMenuItem::separator(app)?;
            let menu = Menu::with_items(app, &[&show, &separator, &start, &pause, &stand_up, &pomodoro, &skip, &separator_two, &settings, &quit])?;

            TrayIconBuilder::new()
                .icon(app.default_window_icon().expect("application icon is missing").clone())
                .menu(&menu)
                .show_menu_on_left_click(false)
                .tooltip("SittingTime")
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "show" => show_window(app),
                    "start" => mutate_timer(app, TimerEngine::start),
                    "pause" => mutate_timer(app, TimerEngine::pause),
                    "stand-up" => mutate_timer(app, |engine| { engine.set_mode(TimerMode::StandUp); engine.start(); }),
                    "pomodoro" => mutate_timer(app, |engine| { engine.set_mode(TimerMode::Pomodoro); engine.start(); }),
                    "skip" => mutate_timer(app, TimerEngine::skip),
                    "settings" => { show_window(app); let _ = app.emit("open-settings", ()); }
                    "quit" => app.exit(0),
                    _ => {}
                })
                .build(app)?;

            if let Some(window) = app.get_webview_window("main") {
                if start_minimized {
                    let _ = window.hide();
                }
                let app_handle = app.handle().clone();
                window.on_window_event(move |event| {
                    if let WindowEvent::CloseRequested { api, .. } = event {
                        api.prevent_close();
                        if let Some(window) = app_handle.get_webview_window("main") {
                            let _ = window.hide();
                        }
                    }
                });
            }

            start_timer_worker(app.handle().clone());
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running SittingTime");
}
