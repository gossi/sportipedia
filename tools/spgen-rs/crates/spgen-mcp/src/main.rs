//! The MCP server: spgen's read-only face for agents. One binary, stdio
//! transport (newline-delimited JSON-RPC 2.0, the MCP protocol's local
//! transport), five tools, all annotated read-only. The server writes
//! nothing: not a source file, not a format pass — that stays with the
//! bindings. It answers what exists, what is available to call, where
//! things live, what they are named, whether the model is complete, and
//! what the manual says.

mod server;
mod tools;

fn main() {
    server::serve();
}
