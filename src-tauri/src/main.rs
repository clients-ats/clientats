// Prevents additional console window on Windows in release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::time::Duration;
use std::fs::OpenOptions;
use std::io::Write;
use port_check::is_port_reachable;
use tauri::Manager;

#[cfg(not(debug_assertions))]
use std::net::TcpListener;
#[cfg(not(debug_assertions))]
use std::sync::{Arc, Mutex};
#[cfg(not(debug_assertions))]
use std::process::{Command, Child};


const DEFAULT_PORT: u16 = 4000;
const MAX_STARTUP_WAIT_SECS: u64 = 30;

#[cfg(not(debug_assertions))]
struct PhoenixProcess(Arc<Mutex<Option<Child>>>);

// Helper function to write logs to a file
fn log_to_file(log_path: &std::path::Path, message: &str) {
    if let Ok(mut file) = OpenOptions::new()
        .create(true)
        .append(true)
        .open(log_path)
    {
        let timestamp = chrono::Local::now().format("%Y-%m-%d %H:%M:%S");
        let _ = writeln!(file, "[{}] {}", timestamp, message);
    }
    // Also print to stdout for dev mode
    println!("{}", message);
}

#[cfg(not(debug_assertions))]
fn get_free_port() -> Option<u16> {
    TcpListener::bind("127.0.0.1:0")
        .and_then(|listener| listener.local_addr())
        .map(|addr| addr.port())
        .ok()
}

fn wait_for_server(port: u16, log_path: &std::path::Path) -> bool {
    log_to_file(log_path, &format!("Waiting for Phoenix server on port {}...", port));
    let start = std::time::Instant::now();

    while start.elapsed().as_secs() < MAX_STARTUP_WAIT_SECS {
        if is_port_reachable(format!("127.0.0.1:{}", port)) {
            log_to_file(log_path, "Phoenix server is ready!");
            return true;
        }
        std::thread::sleep(Duration::from_millis(500));
    }

    log_to_file(log_path, &format!("Phoenix server failed to start within {} seconds", MAX_STARTUP_WAIT_SECS));
    false
}

fn main() {
    // Create log file path
    #[cfg(debug_assertions)]
    let log_path_val = std::path::PathBuf::from("/tmp/clientats-tauri-dev.log");

    #[cfg(not(debug_assertions))]
    let log_path_val = {
        let temp_dir = std::env::temp_dir();
        temp_dir.join("clientats-tauri.log")
    };

    let log_path = log_path_val.clone();
    
    #[cfg(not(debug_assertions))]
    let phoenix_child: Arc<Mutex<Option<Child>>> = Arc::new(Mutex::new(None));
    #[cfg(not(debug_assertions))]
    let phoenix_child_clone = Arc::clone(&phoenix_child);

    // In dev mode, just verify Phoenix is running - Tauri uses devUrl from config
    #[cfg(debug_assertions)]
    {
        log_to_file(&log_path, &format!("Development mode: Checking Phoenix on port {}...", DEFAULT_PORT));
        log_to_file(&log_path, &format!("Log file: {}", log_path.display()));
        if !wait_for_server(DEFAULT_PORT, &log_path) {
            log_to_file(&log_path, &format!("ERROR: Phoenix server not running on port {}!", DEFAULT_PORT));
            log_to_file(&log_path, "Start it with: mix phx.server");
            // In dev mode we don't exit, maybe it will start later or user will start it
        } else {
            log_to_file(&log_path, "Phoenix is ready! Launching Tauri window...");
        }
    }

    let builder = tauri::Builder::default();
    
    #[cfg(not(debug_assertions))]
    let builder = builder.manage(PhoenixProcess(phoenix_child_clone));

    builder
        .plugin(tauri_plugin_shell::init())
        .setup(move |app| {
            // In dev mode, window loads devUrl automatically from tauri.conf.json
            #[cfg(debug_assertions)]
            {
                log_to_file(&log_path, "Dev mode: Window will load from devUrl in config");
                let window = app.get_webview_window("main").expect("Failed to get main window");
                let url = format!("http://localhost:{}", DEFAULT_PORT);
                window.navigate(url.parse().unwrap()).expect("Failed to navigate to Phoenix");
                return Ok(());
            }

            // Production mode: Start embedded Phoenix server
            #[cfg(not(debug_assertions))]
            {
                log_to_file(&log_path, "Production mode: Starting embedded Phoenix server");
                log_to_file(&log_path, &format!("Log file location: {}", log_path.display()));

                let port = get_free_port().unwrap_or(DEFAULT_PORT);
                let url = format!("http://127.0.0.1:{}", port);
                log_to_file(&log_path, &format!("Selected port: {}", port));

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

                log_to_file(&log_path, &format!("Phoenix executable path: {:?}", phoenix_path));

                // Check if Phoenix executable exists
                if !phoenix_path.exists() {
                    log_to_file(&log_path, &format!("ERROR: Phoenix executable not found at {:?}", phoenix_path));
                    panic!("Phoenix executable not found");
                }
                log_to_file(&log_path, "Phoenix executable found");

                // Get database directory in user's home
                let db_dir = app.path().app_data_dir()
                    .expect("Failed to get app data dir");

                std::fs::create_dir_all(&db_dir)
                    .expect("Failed to create app data directory");

                let db_path = db_dir.join("clientats.db");
                log_to_file(&log_path, &format!("Database path: {:?}", db_path));

                // Step 1: Run migrations synchronously
                log_to_file(&log_path, "Running database migrations...");
                let migrate_result = Command::new(&phoenix_path)
                    .arg("eval")
                    .arg("Clientats.Release.migrate()")
                    .env("DATABASE_PATH", db_path.to_str().unwrap())
                    .env("MIX_ENV", "prod")
                    .output();

                match migrate_result {
                    Ok(output) => {
                        if !output.status.success() {
                            let stderr = String::from_utf8_lossy(&output.stderr);
                            let stdout = String::from_utf8_lossy(&output.stdout);
                            log_to_file(&log_path, &format!("Migration stderr: {}", stderr));
                            log_to_file(&log_path, &format!("Migration stdout: {}", stdout));
                            log_to_file(&log_path, "Migration completed with warnings");
                        } else {
                            log_to_file(&log_path, "Migrations completed successfully");
                        }
                    }
                    Err(e) => {
                        log_to_file(&log_path, &format!("Failed to run migrations: {}", e));
                    }
                }

                // Step 2: Start Phoenix server
                log_to_file(&log_path, "Starting Phoenix server...");
                
                // Use "exec" to replace the shell process with the Phoenix process.
                // This ensures that child.kill() kills the Phoenix server directly
                // rather than just the wrapper script.
                let mut cmd = if cfg!(target_os = "windows") {
                    let mut c = Command::new(&phoenix_path);
                    c.arg("start");
                    c
                } else {
                    let mut c = Command::new("sh");
                    c.arg("-c");
                    c.arg(format!("exec \"$1\" start"));
                    c.arg("--");
                    c.arg(&phoenix_path);
                    c
                };

                cmd.env("PORT", port.to_string())
                   .env("MIX_ENV", "prod")
                   .env("PHX_SERVER", "true")
                   .env("DATABASE_PATH", db_path.to_str().unwrap());

                match cmd.spawn() {
                    Ok(child) => {
                        log_to_file(&log_path, &format!("Phoenix server process started with PID: {}", child.id()));
                        let mut phoenix_child_lock = phoenix_child.lock().unwrap();
                        *phoenix_child_lock = Some(child);
                    }
                    Err(e) => {
                        log_to_file(&log_path, &format!("Failed to spawn Phoenix server: {}", e));
                        panic!("Failed to start Phoenix server");
                    }
                }

                // Step 3: Wait for port to be reachable
                log_to_file(&log_path, "Waiting for Phoenix server to be ready...");
                if !wait_for_server(port, &log_path) {
                    log_to_file(&log_path, "FATAL: Phoenix server failed to start");
                    panic!("Phoenix server failed to start");
                }

                // Step 4: Create window with URL
                log_to_file(&log_path, &format!("Creating window with URL: {}", url));

                use tauri::WebviewUrl;
                use tauri::WebviewWindowBuilder;

                let window_builder = WebviewWindowBuilder::new(app, "main", WebviewUrl::External(url.parse().unwrap()))
                    .title("ClientATS - Job Scraping & Management")
                    .inner_size(1280.0, 900.0)
                    .min_inner_size(800.0, 600.0)
                    .resizable(true);

                match window_builder.build() {
                    Ok(window) => {
                        log_to_file(&log_path, "Window created successfully");
                        match window.show() {
                            Ok(_) => log_to_file(&log_path, "Window shown"),
                            Err(e) => log_to_file(&log_path, &format!("Failed to show window: {}", e)),
                        }
                    }
                    Err(e) => {
                        log_to_file(&log_path, &format!("Failed to create window: {}", e));
                        panic!("Failed to create window");
                    }
                }

                log_to_file(&log_path, "Tauri setup complete");
                Ok(())
            }
        })
        .build(tauri::generate_context!())
        .expect("error while building tauri application")
        .run(move |_app_handle, event| {
            if let tauri::RunEvent::Exit = event {
                #[cfg(not(debug_assertions))]
                {
                    let phoenix_process = _app_handle.state::<PhoenixProcess>();
                    let mut child_lock = phoenix_process.0.lock().unwrap();
                    if let Some(mut child) = child_lock.take() {
                        println!("Killing Phoenix server process...");
                        let _ = child.kill();
                    }
                }
            }
        });
}
