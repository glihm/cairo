///! Utils functions to parse Scarb configuration and directories.
///!
///! This code is not attempted to reproduce what Scarb is doing.
///! Here the objective is to facilitate the import of additional
///! libraries dynamically.
///!
///! As Scarb has a well known structure to manage dependencies,
///! we leverage that here, to find the source required by the project.
///!
///! In the future, Scarb may also integrate the `cairo_project.toml`
///! because they control how the database of cairo projects is built
///! and hence they location of the sosurces.
///! This means keeping parsing `Scarb.toml` file will keep this repo
///! functional with Scarb.

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use toml::Value;

/// Library information from Scarb.toml file.
/// The name and the revision are enough to find
/// the library in the cache directory of Scarb.
#[derive(Debug)]
pub struct LibInfo {
    pub name: String,
    pub rev: String,
}

/// Autodetects Scarb libraries from Scarb.toml
/// file and adds them to the libraries for the compiler.
///
/// * `path` - Path where `Scarb.toml` file is expected to be.
/// * `libs` - Cairo libraries where Scarb dependencies may be added.
pub fn autodetect_libs(path: &PathBuf, libs: &mut HashMap<String, PathBuf>) {

    let scarb_toml_path = PathBuf::from(path).join("Scarb.toml");

    let scarb_libs = get_libs_from_toml(&scarb_toml_path);

    // TODO: do we need this path to be configurable from CLI?
    let scarb_cache_dir = dirs::home_dir()
        .expect("Failed to get home directory.")
        .join(".cache/scarb/registry/git/checkouts/");

    for lib in scarb_libs {
        if let Some(lib_path) = detect_lib_from_cache_dir(&scarb_cache_dir, &lib) {
            libs.insert(lib.name, lib_path);
        }
    }
}

/// Parses the given cache directory of Scarb to find the library
/// present in the `info`, and return the path of the source code
/// of that library, if any.
///
/// To match Scarb guidelines, revision is highly recommended.
/// If no revision is given, this function takes the most recent
/// directory in the cache that matches the library name.
///
/// * `root_dir` - root directory of the Scarb cache.
/// * `info` - info of the library that we need source to find the source path.
fn detect_lib_from_cache_dir(
    root_dir: &Path,
    info: &LibInfo,
) -> Option<PathBuf> {
    // The `-` is important as some libraries may contains the same substring
    // as others. And `-` is an invalid char in the Scarb.toml dependencies keys.
    let libname = &format!("{}-", info.name.as_str());
    let rev = info.rev.as_str();

    // Get a list of directories in the root directory starting with
    // the libname as prefix.
    let lib_dirs = get_subdirectories(root_dir, libname);

    let mut found_directory = None;

    // If a revision is given, let's try to find it directly.
    if !rev.is_empty() {
        for dir in lib_dirs.iter() {
            let rev_path = dir.join(rev);
            if rev_path.exists() && rev_path.is_dir() {
                found_directory = Some(dir);
                break;
            }
        }
    }

    if let Some(rev_d) = found_directory {
        Some(rev_d.clone())
    } else {
        // If the target directory with rev is not found, select the most recent revision.
        found_directory = lib_dirs.iter().max_by_key(|&dir| {
            fs::metadata(dir)
                .expect("Failed to read metadata")
                .modified()
                .expect("Failed to read modification time")
        });
        
        if let Some(d) = found_directory {
            if let Some(rev_d) = get_most_recent_subdirectory(d) {
                return Some(rev_d.clone());
            }
        }

        None
    }
}

/// Parses Scarb.toml file to collect all the dependencies
/// coming from a git repository and returns information
/// of those libraries.
///
/// * `path` - Path of the `Scarb.toml` file to parse.
fn get_libs_from_toml(
    path: &Path,
) -> Vec<LibInfo> {

    if !path.exists() {
        return Vec::new();
    }

    let toml_str = fs::read_to_string(path)
        .expect(format!("Failed to read TOML file from '{:?}'.", path).as_str());

    // Parse the TOML string into a Value object
    let parsed_toml: Value = toml::from_str(&toml_str)
        .expect(format!("Failed to parse TOML file from '{:?}'.", path).as_str());

    let mut libs: Vec<LibInfo> = Vec::new();

    // Access values from the parsed TOML
    match parsed_toml.get("dependencies").and_then(Value::as_table) {
        Some(deps) => {
            for (libname, table) in deps {
                // Only consider checking the rev for git dependencies.
                // TODO: consider adjusting this depending Scarb evolution.
                if let Some(table) = Value::as_table(table) {
                    if !table.contains_key("git") {
                        continue;
                    }
                } else {
                    continue;
                }

                match table.get("rev").and_then(Value::as_str) {
                    Some(rev) => libs.push(LibInfo { name: libname.to_string(), rev: rev.to_string() }),
                    // TODO: check if it's the better way to handle no revisions.
                    None => libs.push(LibInfo { name: libname.to_string(), rev: String::from("") }),
                }
            }
        },
        None => println!("No dependencies table found in TOML file '{:?}'.", path),
    }

    libs
}

/// Lists all the subdirectories of the given path.
///
/// * `path` - Path we want to list sub-directores.
/// * `prefix` - Prefix that must be found to include the sub-directory.
fn get_subdirectories(path: &Path, prefix: &str) -> Vec<PathBuf> {
    fs::read_dir(path)
        .expect(format!("Failed to read directory {:?}", path).as_str())
        .filter_map(|entry| {
            let entry = entry.expect("Failed to read directory entry");
            let path = entry.path();
            // TODO: add some refacto here to ensure we handle possible errors.
            if !prefix.is_empty() && path.is_dir() && path.file_name().unwrap().to_str().unwrap().starts_with(prefix) {
                Some(path)
            } else {
                if prefix.is_empty() {
                    Some(path)
                } else {
                    None
                }
            }
        })
        .collect::<Vec<PathBuf>>()
}

/// Searches for the most recently modified subdirectory.
///
/// * `dir_path` - Path where the most recent subdirectory must be found.
fn get_most_recent_subdirectory(dir_path: &Path) -> Option<PathBuf> {
    let subdirs = match fs::read_dir(dir_path) {
        Ok(entries) => {
            let mut subdirs: Vec<PathBuf> = entries
                .filter_map(|entry| {
                    let path = entry.ok()?.path();
                    if path.is_dir() {
                        Some(path)
                    } else {
                        None
                    }
                })
                .collect();
            // TODO: ugly? Need proper checks.
            subdirs.sort_by(|a, b| b.metadata().unwrap().modified().unwrap().cmp(&a.metadata().unwrap().modified().unwrap()));
            subdirs
        }
        Err(_) => return None,
    };

    subdirs.into_iter().next()
}

