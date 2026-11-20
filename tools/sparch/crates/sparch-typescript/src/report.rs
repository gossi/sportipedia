//! Grouped report — the BE report culture: the report is how the
//! operator decides what to run next; deferrals guide, blocks fail.
//! Empty groups print nothing; `--dry-run` uses the same shape in future
//! tense. Exit status is nonzero only on Blocked/Failed.

#[derive(Default)]
pub struct Report {
    created: Vec<String>,
    updated: Vec<(String, Vec<String>)>,
    ignored: Vec<String>,
    deferred_files: Vec<(String, String)>,
    deferred_units: Vec<(String, Vec<String>)>,
    blocked: Vec<(String, String)>,
    failed: Vec<(String, String)>,
    unresolved: Vec<String>,
}

impl Report {
    pub fn created(&mut self, path: &str) {
        self.created.push(path.to_string());
    }

    pub fn would_create(&mut self, path: &str) {
        self.created
            .push(format!("{path} (would create — nothing written)"));
    }

    pub fn updated(&mut self, path: &str, units: Vec<String>) {
        self.updated.push((path.to_string(), units));
    }

    pub fn would_update(&mut self, path: &str, units: Vec<String>) {
        self.updated.push((
            path.to_string(),
            units
                .into_iter()
                .map(|u| {
                    if u.ends_with("(rewritten)") {
                        u.replacen("(rewritten)", "(would rewrite)", 1)
                    } else {
                        format!("{u} (would add)")
                    }
                })
                .collect(),
        ));
    }

    pub fn ignored(&mut self, path: &str) {
        self.ignored.push(path.to_string());
    }

    pub fn deferred(&mut self, path: &str, reason: String) {
        self.deferred_files.push((path.to_string(), reason));
    }

    pub fn deferred_units(&mut self, path: &str, units: Vec<String>) {
        if !units.is_empty() {
            self.deferred_units.push((path.to_string(), units));
        }
    }

    pub fn blocked(&mut self, path: &str, reason: String) {
        self.blocked.push((path.to_string(), reason));
    }

    pub fn failed(&mut self, path: &str, reason: String) {
        self.failed.push((path.to_string(), reason));
    }

    pub fn unresolved(&mut self, note: String) {
        self.unresolved.push(note);
    }

    pub fn exit_code(&self) -> i32 {
        if self.blocked.is_empty() && self.failed.is_empty() {
            0
        } else {
            1
        }
    }

    pub fn render(&self) -> Vec<String> {
        let mut lines = Vec::new();
        if !self.created.is_empty() {
            lines.push("Created".to_string());
            lines.extend(self.created.iter().map(|p| format!("  {p}")));
        }
        if !self.updated.is_empty() {
            lines.push("Updated".to_string());
            for (path, units) in &self.updated {
                lines.push(format!("  {path}"));
                for unit in units {
                    lines.push(format!("    + {unit}"));
                }
            }
        }
        if !self.ignored.is_empty() {
            lines.push("Ignored".to_string());
            lines.extend(
                self.ignored
                    .iter()
                    .map(|p| format!("  {p} (everything present)")),
            );
        }
        if !self.deferred_files.is_empty() {
            lines.push("Ignored".to_string());
            for (path, reason) in &self.deferred_files {
                lines.push(format!("  {path} — deferred: {reason}"));
            }
        }
        if !self.deferred_units.is_empty() {
            for (path, units) in &self.deferred_units {
                lines.push(format!("  {path} — deferred units: {}", units.join(", ")));
            }
        }
        if !self.unresolved.is_empty() {
            lines.push("Unresolved".to_string());
            lines.extend(self.unresolved.iter().map(|note| format!("  {note}")));
        }
        if !self.blocked.is_empty() {
            lines.push("Blocked".to_string());
            for (path, reason) in &self.blocked {
                lines.push(format!("  {path}: {reason}"));
            }
        }
        if !self.failed.is_empty() {
            lines.push("Failed".to_string());
            for (path, reason) in &self.failed {
                lines.push(format!("  {path}: {reason}"));
            }
        }
        if lines.is_empty() {
            lines.push("nothing to do".to_string());
        }
        lines
    }
}
