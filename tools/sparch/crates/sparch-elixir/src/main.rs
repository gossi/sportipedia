fn main() {
    let code = sparch_elixir::cli::main(std::env::args().skip(1));
    std::process::exit(code);
}
