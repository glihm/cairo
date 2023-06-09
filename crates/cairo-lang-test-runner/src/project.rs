///! Project files parsing related functions.

use std::fs;
use std::path::{Path, PathBuf};
use toml::Value;

/// Parses cairo_project.toml file to extract crate_roots.
///
/// * `path` - Path of the `cairo_project.toml` file to parse.
/// * `name` - Crate for which we want the path.
pub fn get_root_path_from_toml(
    path: &Path,
    name: &str,
) -> Option<PathBuf> {

    if !path.exists() {
        println!("Can't locate file `cairo_project.toml` at '{:?}' [{}].", path, name);
        return None;
    }

    let toml_str = fs::read_to_string(path)
        .expect(format!("Failed to read TOML file from '{:?}'.", path).as_str());

    let parsed_toml: Value = toml::from_str(&toml_str)
        .expect(format!("Failed to parse TOML file from '{:?}'.", path).as_str());

    match parsed_toml.get("crate_roots").and_then(Value::as_table) {
        Some(roots) => {
            for (root_name, path) in roots {
                if root_name == name {
                    return Some(PathBuf::from(Value::as_str(path).unwrap()));
                }
            }

            return None;
        },
        None => {
            println!("Can't get crate_roots in file");
            None
        }
    }
}
