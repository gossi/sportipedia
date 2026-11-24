fn main() {
    let code = sparch::cli::main(std::env::args().skip(1));
    std::process::exit(code);
}
