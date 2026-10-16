fn main() {
    // tauri-build only reruns when tauri.conf.json changes, so a new icon.ico
    // would otherwise leave the old icon embedded in the exe (taskbar, Explorer).
    println!("cargo:rerun-if-changed=icons");
    tauri_build::build()
}
