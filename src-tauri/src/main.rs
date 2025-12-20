// Prevents additional console window on Windows in release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri::Manager;
use std::time::Duration;
use port_check::is_port_reachable;

#[cfg(not(debug_assertions))]
use std::process::Command;

const DEFAULT_PORT: u16 = 4000;
const MAX_STARTUP_WAIT_SECS: u64 = 30;

fn wait_for_server(port: u16) -> bool {
    println!("Waiting for Phoenix server on port {}...", port);
    let start = std::time::Instant::now();

    while start.elapsed().as_secs() < MAX_STARTUP_WAIT_SECS {
        if is_port_reachable(format!("127.0.0.1:{}", port)) {
            println!("Phoenix server is ready!");
            return true;
        }
        std::thread::sleep(Duration::from_millis(500));
    }

    eprintln!("Phoenix server failed to start within {} seconds", MAX_STARTUP_WAIT_SECS);
    false
}

fn main() {
    let port = DEFAULT_PORT;
    let url = format!("http://127.0.0.1:{}", port);

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .setup(move |app| {
            // In dev mode, Phoenix is already running separately
            // Skip the embedded server startup
            #[cfg(debug_assertions)]
            {
                println!("Development mode: Assuming Phoenix is running on port {}...", port);
                // Just wait for the existing server
                if !wait_for_server(port) {
                    panic!("Phoenix server not reachable on port {}. Start it with 'mix phx.server'", port);
                }

                let window = app.get_webview_window("main").unwrap();
                window.navigate(url.parse().unwrap()).unwrap();
                return Ok(());
            }

            // Production mode: Start embedded Phoenix server
            #[cfg(not(debug_assertions))]
            {
                // Get the Phoenix release path
                let phoenix_path = if cfg!(target_os = "macos") {
                    app.path().resource_dir()
                        .expect("Failed to get resource dir")
                        .join("phoenix")
                        .join("bin")
                        .join("clientats")
                } else if cfg!(target_os = "windows") {
                    app.path().resource_dir()
                        .expect("Failed to get resource dir")
                        .join("phoenix")
                        .join("bin")
                        .join("clientats.bat")
                } else {
                    app.path().resource_dir()
                        .expect("Failed to get resource dir")
                        .join("phoenix")
                        .join("bin")
                        .join("clientats")
                };

                println!("Phoenix executable path: {:?}", phoenix_path);

                // Get database directory in user's home
                let db_dir = app.path().app_data_dir()
                    .expect("Failed to get app data dir");

                std::fs::create_dir_all(&db_dir)
                    .expect("Failed to create app data directory");

                let db_path = db_dir.join("clientats.db");
                println!("Database path: {:?}", db_path);

                // Step 1: Run migrations synchronously
                println!("Running database migrations...");
            let migrate_result = if cfg!(target_os = "windows") {
                Command::new(&phoenix_path)
                    .arg("eval")
                    .arg("Clientats.Release.migrate()")
                    .env("DATABASE_PATH", db_path.to_str().unwrap())
                    .env("MIX_ENV", "prod")
                    .output()
            } else {
                Command::new(&phoenix_path)
                    .arg("eval")
                    .arg("Clientats.Release.migrate()")
                    .env("DATABASE_PATH", db_path.to_str().unwrap())
                    .env("MIX_ENV", "prod")
                    .output()
            };

            match migrate_result {
                Ok(output) => {
                    if !output.status.success() {
                        eprintln!("Migration warning: {:?}", String::from_utf8_lossy(&output.stderr));
                    } else {
                        println!("Migrations completed successfully");
                    }
                }
                Err(e) => eprintln!("Failed to run migrations: {}", e),
            }

            // Step 2: Start Phoenix server
            println!("Starting Phoenix server...");
            #[cfg(target_os = "windows")]
            let mut cmd = Command::new(&phoenix_path);

            #[cfg(not(target_os = "windows"))]
            let mut cmd = {
                let mut c = Command::new(&phoenix_path);
                c.arg("start");
                c
            };

            cmd.env("PORT", port.to_string())
               .env("MIX_ENV", "prod")
               .env("PHX_SERVER", "true")
               .env("DATABASE_PATH", db_path.to_str().unwrap())
               .spawn()
               .expect("Failed to start Phoenix server");

            // Step 3: Wait for port to be reachable
            if !wait_for_server(port) {
                panic!("Phoenix server failed to start");
            }

                // Step 4: Create window and load the app
                let window = app.get_webview_window("main").unwrap();
                window.navigate(url.parse().unwrap()).unwrap();

                Ok(())
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
