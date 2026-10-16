# Instructions for Future Coding Agents

- Keep the app lightweight and Windows-first.
- Keep timer business logic primarily in Rust; the frontend is a renderer and command client.
- Store timestamps/deadlines, not interval counters, as the source of truth.
- Frontend polling may refresh the display, but it must only render Rust snapshots and must never calculate authoritative elapsed time.
- Do not introduce React, Vue, Next.js, Tailwind, state-management libraries, SQLite, authentication, telemetry, remote APIs, or a backend server.
- Prefer official Tauri-maintained plugins when a plugin is necessary.
- Preserve tray-first behavior: closing the window hides it, and only an explicit Quit action exits.
- Keep the UI compact, native-looking, accessible, and visually minimal.
- Avoid unnecessary dependencies and broad refactors.
- Keep timer modes and session phases represented with clear Rust enums and structs.
- Persist only the necessary local settings and timer state.
- Run `npm run build` and `npm run tauri build` on a Windows development machine when applicable.
- Check tray behavior, window close behavior, restart, and sleep/wake accuracy after timer changes.
- Keep the pinned Rust toolchain unless the Windows Smart App Control compatibility issue is verified as resolved.
