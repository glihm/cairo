//! Compiles and runs a Cairo program.

use anyhow::Ok;
use cairo_lang_test_runner::TestRunner;
use clap::Parser;

/// Command line args parser.
/// Exits with 0/1 if the input is formatted correctly/incorrectly.
#[derive(Parser, Debug)]
#[clap(version, verbatim_doc_comment)]
struct Args {
    /// The path to compile and run its tests.
    path: String,
    /// The filter for the tests, running only tests containing the filter string.
    #[arg(short, long, default_value_t = String::default())]
    filter: String,
    /// Should we run ignored tests as well.
    #[arg(long, default_value_t = false)]
    include_ignored: bool,
    /// Should we run only the ignored tests.
    #[arg(long, default_value_t = false)]
    ignored: bool,
    /// Should we add the starknet plugin to run the tests.
    #[arg(long, default_value_t = false)]
    starknet: bool,
    /// Additional libraries paths to add to the project.
    #[arg(short, long, num_args = 0.., value_delimiter = ',')]
    libs: Vec<String>,
}

fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    println!("LIBS: {:?}", args.libs);

    // Here we want a special argument like --scarb
    // to actually do the parsing of Scarb.toml + find the dirs.
    // But in the docker case.. we must indicate where the scarb is :/
    // Not very beautiful, and this project should not directly depend
    // on scarb as it's more generic than scarb.
    // What we are trying to add is the possibility to add additional
    // crates/libraries that the compiler can include without
    // having those libraries explicitely named in the cairo_project.toml.

    let runner = TestRunner::new(
        &args.path,
        &args.filter,
        args.include_ignored,
        args.ignored,
        args.starknet,
    )?;
    runner.run()?;

    Ok(())
}
