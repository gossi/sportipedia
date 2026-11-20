//! MCP smoke: start the real server, drive the protocol with newline
//! JSON-RPC exactly as a client does, assert the five tools' answers.
//! No SDK needed in the test — the wire is the contract.

use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use serde_json::Value;

fn fixtures() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../fixtures")
        .canonicalize()
        .unwrap()
}

fn sandbox() -> PathBuf {
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let root = std::env::temp_dir().join(format!("spgen-mcp-{unique}"));
    copy(&fixtures().join("repo"), &root);
    std::fs::create_dir_all(root.join("docs")).unwrap();
    copy(
        &fixtures().join("domain-model"),
        &root.join("docs/domain-model"),
    );
    root
}

fn copy(from: &Path, to: &Path) {
    std::fs::create_dir_all(to).unwrap();
    for entry in std::fs::read_dir(from).unwrap() {
        let entry = entry.unwrap();
        let target = to.join(entry.file_name());
        if entry.file_type().unwrap().is_dir() {
            copy(&entry.path(), &target);
        } else {
            std::fs::copy(entry.path(), &target).unwrap();
        }
    }
}

/// Write every request line, read one response per line (all requests
/// here carry ids), close stdin, reap the server.
fn drive(requests: &[String]) -> Vec<Value> {
    let binary = env!("CARGO_BIN_EXE_spgen-mcp");
    let mut child = Command::new(binary)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .expect("start spgen-mcp");
    {
        let stdin = child.stdin.as_mut().unwrap();
        for request in requests {
            writeln!(stdin, "{request}").unwrap();
        }
        stdin.flush().unwrap();
    }
    // close stdin first: the server then finishes its queue and sees EOF,
    // so a short answer count surfaces as a failed assert, never a hang
    drop(child.stdin.take());
    let mut reader = BufReader::new(child.stdout.take().unwrap());
    let mut responses = Vec::new();
    for _ in requests {
        let mut line = String::new();
        assert!(
            reader.read_line(&mut line).unwrap() > 0,
            "server closed before answering every request"
        );
        responses.push(serde_json::from_str(line.trim()).expect("response is JSON"));
    }
    child.wait().expect("wait for server");
    responses
}

fn initialize(id: u8) -> String {
    format!(
        r#"{{"jsonrpc":"2.0","id":{id},"method":"initialize","params":{{"protocolVersion":"2025-06-18","capabilities":{{}},"clientInfo":{{"name":"test","version":"0"}}}}}}"#
    )
}

fn call(id: u8, tool: &str, arguments: &str) -> String {
    format!(
        r#"{{"jsonrpc":"2.0","id":{id},"method":"tools/call","params":{{"name":"{tool}","arguments":{{{arguments}}}}}}}"#
    )
}

fn text_of(response: &Value) -> String {
    response["result"]["content"][0]["text"]
        .as_str()
        .unwrap_or_default()
        .to_string()
}

#[test]
fn handshake_and_tool_catalog() {
    let responses = drive(&[
        initialize(1),
        r#"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#.to_string(),
        r#"{"jsonrpc":"2.0","id":3,"method":"nope"}"#.to_string(),
    ]);
    let init = &responses[0];
    assert_eq!(init["result"]["protocolVersion"], "2025-06-18");
    assert!(init["result"]["capabilities"]["tools"].is_object());
    assert_eq!(init["result"]["serverInfo"]["name"], "spgen");

    let tools = responses[1]["result"]["tools"].as_array().unwrap();
    let names: Vec<&str> = tools.iter().map(|t| t["name"].as_str().unwrap()).collect();
    assert_eq!(
        names,
        vec![
            "spgen_capabilities",
            "spgen_validate",
            "spgen_man",
            "spgen_arch_location",
            "spgen_arch_name",
        ]
    );
    for tool in tools {
        assert_eq!(tool["annotations"]["readOnlyHint"], true);
    }

    assert_eq!(responses[2]["error"]["code"], -32601);
}

#[test]
fn capabilities_man_and_arch_answer_over_the_wire() {
    let root = sandbox();
    let r = root.display().to_string();
    let responses = drive(&[
        initialize(1),
        call(
            2,
            "spgen_capabilities",
            &format!(r#""target": "typescript", "repo_root": "{r}""#),
        ),
        call(3, "spgen_man", r#""generator": "read_model""#),
        call(
            4,
            "spgen_arch_location",
            &format!(r#""generator": "command", "element": "create-widget", "repo_root": "{r}""#),
        ),
    ]);

    let text = text_of(&responses[1]);
    assert!(text.contains("pnpm spgen feature <read-model>"), "{text}");
    assert!(
        !text.contains("mix sp.gen"),
        "filtered to typescript:\n{text}"
    );
    let langs = responses[1]["result"]["structuredContent"]["languages"]
        .as_array()
        .unwrap();
    assert_eq!(langs.len(), 1);

    let man = text_of(&responses[2]);
    assert!(man.contains("SYNOPSIS"), "a rendered man page:\n{man}");
    assert!(
        man.contains("mix sp.gen.read_model [options] <READ-MODEL>"),
        "{man}"
    );
    assert!(
        man.contains("The queryable projection of the events"),
        "{man}"
    );
    assert!(!man.contains(".SH"), "no roff noise:\n{man}");

    let arch_text = text_of(&responses[3]);
    assert!(
        arch_text.contains("operations/create_widget/command.ex"),
        "{arch_text}"
    );
    assert_eq!(
        responses[3]["result"]["structuredContent"]["location:module"]
            .as_str()
            .unwrap(),
        "Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget"
    );

    let _ = std::fs::remove_dir_all(&root);
}

#[test]
fn validate_is_structured_and_unknown_tools_answer_errors() {
    let root = sandbox();
    let r = root.display().to_string();
    let responses = drive(&[
        initialize(1),
        call(2, "spgen_validate", &format!(r#""repo_root": "{r}""#)),
        call(3, "spgen_bogus", ""),
    ]);
    let findings = responses[1]["result"]["structuredContent"]["findings"]
        .as_array()
        .unwrap();
    assert!(!findings.is_empty());
    assert!(
        findings[0]["element"]
            .as_str()
            .unwrap()
            .starts_with("esdm:")
    );
    assert_eq!(responses[2]["error"]["code"], -32602);
    let _ = std::fs::remove_dir_all(&root);
}

#[test]
fn notifications_are_answered_nothing() {
    // one request + one notification: exactly one response line, then EOF
    let binary = env!("CARGO_BIN_EXE_spgen-mcp");
    let mut child = Command::new(binary)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .unwrap();
    {
        let stdin = child.stdin.as_mut().unwrap();
        writeln!(stdin, "{}", initialize(1)).unwrap();
        writeln!(
            stdin,
            r#"{{"jsonrpc":"2.0","method":"notifications/initialized"}}"#
        )
        .unwrap();
        stdin.flush().unwrap();
    }
    drop(child.stdin.take());
    let mut reader = BufReader::new(child.stdout.take().unwrap());
    let mut line = String::new();
    reader.read_line(&mut line).unwrap();
    assert!(line.contains("\"id\":1"));
    let mut next = String::new();
    assert_eq!(
        reader.read_line(&mut next).unwrap(),
        0,
        "notifications answer nothing"
    );
    child.wait().unwrap();
}
