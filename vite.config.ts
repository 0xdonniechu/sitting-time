import { defineConfig } from "vite";

export default defineConfig({
  clearScreen: false,
  build: {
    rollupOptions: {
      input: ["index.html", "overlay.html"],
    },
  },
  server: {
    port: 1420,
    strictPort: true,
    watch: {
      ignored: ["**/src-tauri/**"],
    },
  },
  envPrefix: ["VITE_", "TAURI_"] ,
});
