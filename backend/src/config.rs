use std::fs::File;
use std::io::BufReader;
use std::path::Path;
use std::sync::{Arc, OnceLock};

use anyhow::{anyhow, Context, Result};
use serde::de::DeserializeOwned;
use serde_json::{Map, Value};

/// Singleton Config that loads a JSON file and resolves "$ref" imports inside objects.
/// - Imported object keys overwrite existing keys (import prevails).
/// - Import nesting is limited by `depth_limit`.
pub struct Config {
    config: Value,
    config_path: String,
}

impl Config {
    /// Returns the global singleton instance, loading "config.json" on first call.
    // Expect: if the config file is not present, it _must_ panic
    pub fn instance() -> Arc<Config> {
        static INSTANCE: OnceLock<Arc<Config>> = OnceLock::new();
        INSTANCE
            .get_or_init(|| {
                let cfg = Config::parse("config.json", true)
                    .expect("failed to load config.json"); // fail-fast on startup
                let config_path = "config.json".to_string();
                Arc::new(Config { config: cfg, config_path})
            })
            .clone()
    }

    pub fn init() {
        let _ = Config::instance();
        println!("[INFO] Init config");
    }

    pub fn get_curr_config_path(&self) -> String {
        self.config_path.clone()
    }

    /// Parse a JSON file at `path`. If `resolve_imports` is true, resolves nested $ref imports.
    pub fn parse<P: AsRef<Path>>(path: P, resolve_imports: bool) -> Result<Value> {
        let file = File::open(&path).with_context(|| {
            format!("failed to open config file '{}'", path.as_ref().display())
        })?;
        let reader = BufReader::new(file);
        let mut v: Value = serde_json::from_reader(reader)
            .with_context(|| format!("failed to parse JSON from '{}'", path.as_ref().display()))?;

        #[cfg(debug_assertions)] {
            println!("[INFO][CONFIG] Loaded debug config!");
            v = v.get_mut("debug").with_context(|| "[FATAL] Expected 'debug' block for debug builds".to_string())?.take();
        }
        #[cfg(not(debug_assertions))] {
            println!("[INFO][CONFIG] Loaded release config!");
            v = v.get_mut("release").with_context(|| format!("[FATAL] Expected 'release' block for release builds"))?.take();
        }

        if resolve_imports {
            Config::resolve_imports(&mut v, 5).context("resolving imports failed")?;
        }
        
        Ok(v)
    }

    /// Recursively traverse `value` and resolve "$ref" entries. Depth limit prevents infinite loops.
    /// Imported object keys overwrite existing keys (import prevails).
    pub fn resolve_imports(value: &mut Value, depth_limit: usize) -> Result<()> {
        fn inner(value: &mut Value, remaining: &mut usize) -> Result<()> {
            match value {
                Value::Object(map) => {
                    // If there's a $ref at this object level, handle it first.
                    if let Some(ref_val) = map.remove("$ref") {
                        if *remaining == 0 {
                            // Log critical and return error
                            eprintln!(
                                "[FATAL] Config file exceeds import depth. depth_limit={}",
                                0usize
                            );
                            return Err(anyhow!(
                                "[FATAL] Config file exceeds import depth."
                            ));
                        }

                        // Decrement remaining depth and parse the referenced path
                        *remaining -= 1;

                        let path = ref_val
                            .as_str()
                            .ok_or_else(|| anyhow!("$ref value is not a string"))?;

                        let mut imported =
                            Config::parse(path, false).with_context(|| format!("parsing '{}'", path))?;

                        // Only merge object imports into object; otherwise assign whole value
                        if let Value::Object(import_map) = &mut imported {
                            // take the map out so we own it, leaving an empty map behind
                            let taken: Map<String, Value> = std::mem::take(import_map);

                            // Imported keys overwrite existing keys (import prevails)
                            for (k, v) in taken {
                                map.insert(k, v);
                            }
                        } else {
                            *value = imported;
                        }

                        // After merging/importing, continue traversal on this (possibly updated) object
                        inner(value, remaining)?;
                        return Ok(());
                    }

                    // No $ref here: traverse children
                    // Collect keys to avoid borrow issues while mutating deeper
                    let keys: Vec<String> = map.keys().cloned().collect();
                    for k in keys {
                        if let Some(child) = map.get_mut(&k) {
                            inner(child, remaining)?;
                        }
                    }
                    Ok(())
                }
                Value::Array(arr) => {
                    for item in arr.iter_mut() {
                        inner(item, remaining)?;
                    }
                    Ok(())
                }
                _ => Ok(()),
            }
        }

        let mut rem = depth_limit;
        inner(value, &mut rem)
    }

    /// Get a Value for a `/`-separated path (default separator "/").
    /// Returns `default` if the path is not found or types mismatch.
    pub fn get_value(&self, path: &str, default: Option<Value>, sep: &str) -> Value {
        match self.get_value_opt(path, sep) {
            Some(v) => v,
            None => {
                eprintln!(
                    "Using undefined config value '{}', returning default value {:?}",
                    path,
                    default
                );
                default.unwrap_or(Value::Null)
            }
        }
    }

    /// Try to get a Value by path; returns None if not found.
    pub fn get_value_opt(&self, path: &str, sep: &str) -> Option<Value> {
        let keys: Vec<&str> = if sep.is_empty() {
            vec![path]
        } else {
            path.split(sep).collect()
        };

        let mut current = &self.config;
        for key in keys {
            match current {
                Value::Object(map) => {
                    current = map.get(key)?;
                }
                _ => return None,
            }
        }
        Some(current.clone())
    }

    /// Generic get that attempts to deserialize the value at `path` into T.
    /// Returns `Ok(T)` or an error describing the failure.
    pub fn get<T: DeserializeOwned>(&self, path: &str, sep: &str) -> Result<T> {
        let v = self
            .get_value_opt(path, sep)
            .ok_or_else(|| anyhow!("config path '{}' not found", path))?;
        let t = serde_json::from_value(v).context("failed to deserialize config value")?;
        Ok(t)
    }

    /// Checks whether a path exists in the configuration.
    pub fn has(&self, path: &str, sep: &str) -> bool {
        self.get_value_opt(path, sep).is_some()
    }
}

/*
Example usage:

fn main() -> Result<()> {
    // initialize logging if desired, e.g. env_logger::init();
    let cfg = Config::instance();

    // get a raw Value (or default)
    let v = cfg.get_value("api/config/details/value", Some(Value::from(42)), "/");
    println!("raw value: {}", v);

    // get typed value
    let num: i32 = cfg.get("api/config/details/value", "/")?;
    println!("typed value: {}", num);

    // check existence
    let exists = cfg.has("api/config/details/value", "/");
    println!("exists: {}", exists);

    Ok(())
}
*/
