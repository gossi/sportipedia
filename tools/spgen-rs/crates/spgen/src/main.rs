fn main() {
    let code = spgen::cli::main(std::env::args().skip(1));
    std::process::exit(code);
}
