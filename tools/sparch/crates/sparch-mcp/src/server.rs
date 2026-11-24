//! Minimal MCP server over the stdio transport: read one JSON-RPC
//! message per line, answer per protocol, never block, never write to
//! stdout outside responses (diagnostics go to stderr).
//!
//! Supported methods: `initialize`, `notifications/initialized`,
//! `ping`, `tools/list`, `tools/call`. Unknown methods answer the
//! JSON-RPC method-not found error, which is the spec's contract for
//! optional features a client may probe.

use serde_json::{Value, json};
use std::io::{BufRead, Write};

use crate::tools;

const PROTOCOL_VERSIONS: &[&str] = &["2024-11-05", "2025-03-26", "2025-06-18"];
const SERVER_INFO: &str = "sparch";

pub fn serve() {
    let stdin = std::io::stdin();
    let stdout = std::io::stdout();
    let mut out = stdout.lock();
    for line in stdin.lock().lines() {
        let Ok(line) = line else { break };
        if line.trim().is_empty() {
            continue;
        }
        let message: Value = match serde_json::from_str(&line) {
            Ok(v) => v,
            Err(_) => {
                writeln!(out, "{}", error(None, -32700, "parse error")).expect("write");
                out.flush().expect("flush");
                continue;
            }
        };
        if let Some(response) = handle(&message) {
            writeln!(out, "{response}").expect("write");
            out.flush().expect("flush");
        }
    }
}

/// Returns None for notifications (messages without an id).
fn handle(message: &Value) -> Option<Value> {
    let id = message.get("id").cloned();
    let method = message.get("method").and_then(Value::as_str)?;
    let params = message.get("params").cloned().unwrap_or(json!({}));
    let result = match method {
        "initialize" => Ok(initialize(&params)),
        "ping" => Ok(json!({})),
        "tools/list" => Ok(tools::list()),
        "tools/call" => tools::call(&params),
        // notifications (no id) are consumed silently; a client that sends
        // one with an id gets an empty result rather than an error
        _ if id.is_none() => return None,
        "notifications/initialized" => return None,
        _ => Err((-32601, format!("method not found: {method}"))),
    };
    let response = match (result, id) {
        (Ok(value), Some(id)) => json!({"jsonrpc": "2.0", "id": id, "result": value}),
        (Err((code, message)), Some(id)) => error(Some(id), code, &message),
        (Ok(_), None) | (Err(_), None) => return None,
    };
    Some(response)
}

fn error(id: Option<Value>, code: i64, message: &str) -> Value {
    json!({
        "jsonrpc": "2.0",
        "id": id,
        "error": {"code": code, "message": message}
    })
}

fn initialize(params: &Value) -> Value {
    let requested = params
        .get("protocolVersion")
        .and_then(Value::as_str)
        .unwrap_or("2025-06-18");
    let version = if PROTOCOL_VERSIONS.contains(&requested) {
        requested
    } else {
        "2025-06-18"
    };
    json!({
        "protocolVersion": version,
        "capabilities": {"tools": {}},
        "serverInfo": {"name": SERVER_INFO, "title": "Sportipedia Generators", "version": env!("CARGO_PKG_VERSION")}
    })
}
