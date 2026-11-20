//! The Elixir source view: tree-sitter based, read-only structural answers
//! plus offset splices — the port of `SpGen.Source`'s questions and the
//! placement outcomes of `SpGen.Merge`, with AST-printing replaced by text
//! insertion into the original bytes.
//!
//! Write-path verdict for the BE (measured by the probe tests and the
//! parity golden, the way M2 measured TypeScript before sparch-typescript):
//! presence is answered from the syntax tree, insertion is a text splice at
//! computed offsets, and the bytes in between are never reprinted.
//! Formatting is not this binary's job: the mix binding runs `mix format`
//! over the api project after a successful write run — the same engine the
//! Elixir tool applied inside `Merge.render/2`, on the same token stream.

use tree_sitter::{Node, Parser, Tree};

/// Directive ranks of the module head — `SpGen.Merge.@directive_ranks`.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Rank {
    Moduledoc = 0,
    Use = 1,
    Import = 2,
    Alias = 3,
    Require = 4,
    Attribute = 5,
}

pub struct ElixirFile {
    text: String,
    tree: Option<Tree>,
}

/// A located local call — the shape of `SpGen.Source.Entry`.
pub struct Entry<'a> {
    node: Node<'a>,
    args: Vec<Node<'a>>,
    file: &'a ElixirFile,
}

impl Entry<'_> {
    pub fn start(&self) -> usize {
        self.node.start_byte()
    }

    pub fn end(&self) -> usize {
        self.node.end_byte()
    }

    /// The rendered first argument — `Merge.first_rendered/1`.
    pub fn first_key(&self) -> String {
        self.args
            .first()
            .map(|arg| self.file.render_arg(*arg))
            .unwrap_or_default()
    }

    /// The rendered last argument — `Source.action_arg/1`, the action atom a
    /// Phoenix route line ends with.
    pub fn action_key(&self) -> String {
        self.args
            .last()
            .map(|arg| self.file.render_arg(*arg))
            .unwrap_or_default()
    }

    /// Every keyword pair of the call's keyword arguments, as
    /// `(key, rendered_value)` in source order — `Source.Entry.pairs/1`.
    /// Repeated keys are kept (the `validates` two-`by:` shape).
    pub fn pairs(&self) -> Vec<(String, String)> {
        let mut out = Vec::new();
        for arg in &self.args {
            collect_pairs(self.file, *arg, &mut out);
        }
        out
    }

    /// The rendered value of keyword `key`, first occurrence — `Entry.kw/2`.
    pub fn kw(&self, key: &str) -> Option<String> {
        self.pairs()
            .into_iter()
            .find(|(k, _)| k == key)
            .map(|(_, v)| v)
    }
}

fn collect_pairs(file: &ElixirFile, node: Node<'_>, out: &mut Vec<(String, String)>) {
    match node.kind() {
        "pair" => {
            if let Some(key) = node.named_child(0)
                && key.kind() == "keyword"
                && let Some(value) = node.named_child(1)
            {
                out.push((file.keyword_name(key), file.render_arg(value)));
            }
        }
        "keywords" | "list" | "tuple" => {
            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                collect_pairs(file, child, out);
            }
        }
        _ => {}
    }
}

impl ElixirFile {
    /// Parse source text; unparsable files yield a tree-less view where
    /// nothing is present — `SpGen.Source.parse/1` with `ast: nil`.
    pub fn parse(text: &str) -> Self {
        let mut parser = Parser::new();
        parser
            .set_language(&tree_sitter_elixir::LANGUAGE.into())
            .expect("elixir grammar");
        let tree = parser.parse(text, None);
        Self {
            text: text.to_string(),
            tree,
        }
    }

    pub fn parsed(&self) -> bool {
        self.tree.is_some()
    }

    pub fn source_text(&self, node: Node<'_>) -> &str {
        &self.text[node.byte_range()]
    }

    /// Debug dump: every node kind with its range. Used by probe tests.
    #[allow(dead_code)]
    pub fn dump(&self) -> String {
        fn walk(out: &mut String, file: &ElixirFile, node: Node<'_>, depth: usize) {
            let summary: String = file
                .source_text(node)
                .chars()
                .take(60)
                .collect::<String>()
                .replace('\n', "\\n");
            out.push_str(&format!(
                "{}{} [{}..{}] \"{summary}\"\n",
                "  ".repeat(depth),
                node.kind(),
                node.start_byte(),
                node.end_byte()
            ));
            let mut cursor = node.walk();
            for child in node.children(&mut cursor) {
                walk(out, file, child, depth + 1);
            }
        }
        let mut out = String::new();
        if let Some(root) = self.tree.as_ref().map(Tree::root_node) {
            walk(&mut out, self, root, 0);
        }
        out
    }

    // -------------------------------------------------------------- names

    /// The dotted module name of the file's `defmodule` — `Source.module_name/1`.
    pub fn module_name(&self) -> Option<String> {
        let defmodule = self.module_call()?;
        let name = defmodule.named_child(1)?;
        Some(self.source_text(name).trim().to_string())
    }

    // ----------------------------------------------------------- presence

    pub fn has_moduledoc(&self) -> bool {
        self.body().iter().any(|child| {
            self.attr_name(*child)
                .is_some_and(|name| name == "moduledoc")
        })
    }

    /// True when the module body carries a `@<attr>` attribute.
    pub fn has_attribute(&self, attr: &str) -> bool {
        self.body()
            .iter()
            .any(|child| self.attr_name(*child).is_some_and(|name| name == attr))
    }

    /// True when `@<attr> …` names the dotted module — `attr_names?/3`.
    pub fn attr_names(&self, attr: &str, module: &str) -> bool {
        self.body().iter().any(|child| {
            self.attr_name(*child).is_some_and(|name| name == attr)
                && self
                    .attr_values(*child)
                    .iter()
                    .any(|value| self.render_arg(*value) == module)
        })
    }

    pub fn has_use(&self, module: &str) -> bool {
        self.has_directive("use", module)
    }

    pub fn has_import(&self, module: &str) -> bool {
        self.has_directive("import", module)
    }

    pub fn has_alias(&self, module: &str) -> bool {
        self.has_directive("alias", module)
    }

    pub fn has_require(&self, module: &str) -> bool {
        self.has_directive("require", module)
    }

    fn has_directive(&self, macro_name: &str, module: &str) -> bool {
        self.body().iter().any(|child| {
            self.call_target(*child)
                .is_some_and(|name| name == macro_name)
                && !is_remote(*child)
                && self
                    .call_args(*child)
                    .first()
                    .is_some_and(|arg| self.render_arg(*arg) == module)
        })
    }

    /// All local calls of `macro_name`, in source order — `Source.calls/2`.
    /// The walk covers the module body and non-function blocks (typedstruct
    /// blocks, router scopes), never function bodies or other modules.
    pub fn calls(&self, macro_name: &str) -> Vec<Entry<'_>> {
        let mut found = Vec::new();
        if let Some(module) = self.module_call()
            && let Some(block) = do_block(module)
        {
            for child in significant(block) {
                self.scan(child, macro_name, &mut found);
            }
        }
        found.sort_by_key(Entry::start);
        found
    }

    fn scan<'a>(&'a self, node: Node<'a>, macro_name: &str, acc: &mut Vec<Entry<'a>>) {
        if node.kind() == "call" {
            let name = self.call_target(node);
            if name.as_deref().is_some_and(|name| name == macro_name) && !is_remote(node) {
                acc.push(Entry {
                    node,
                    args: self.call_args(node),
                    file: self,
                });
            }
            // never look inside other modules or into function bodies
            if matches!(
                name.as_deref(),
                Some("defmodule")
                    | Some("def")
                    | Some("defp")
                    | Some("defmacro")
                    | Some("defmacrop")
            ) {
                return;
            }
        }
        let mut cursor = node.walk();
        for child in node.named_children(&mut cursor) {
            self.scan(child, macro_name, acc);
        }
    }

    /// True when a DSL entry of `macro_name` exists whose first argument
    /// renders to `key` — `Source.entry?/3`.
    pub fn has_entry(&self, macro_name: &str, key: &str) -> bool {
        self.calls(macro_name).iter().any(|e| e.first_key() == key)
    }

    /// True when `describe "subject"` exists (exact) — `has_describe?/2`.
    pub fn has_describe(&self, subject: &str) -> bool {
        self.calls("describe")
            .iter()
            .any(|e| e.args.first().and_then(|arg| e.file.literal_text(*arg)) == Some(subject))
    }

    /// True when any clause of `name/arity` is defined — `Source.has_def?/3`.
    pub fn has_def(&self, name: &str, arity: usize) -> bool {
        self.body().iter().any(|child| {
            self.call_target(*child)
                .is_some_and(|target| target == "def")
                && self
                    .def_head(*child)
                    .is_some_and(|(n, a)| n == name && a == arity)
        })
    }

    /// True when a clause of `name/arity` has `key` (rendered arg) somewhere
    /// in its head — `Source.def_head_has?/4`, e.g. the aggregate's `apply/2`
    /// clauses identified by the event struct they pattern-match.
    pub fn has_def_head_arg(&self, name: &str, arity: usize, key: &str) -> bool {
        self.def_clauses(name, arity).into_iter().any(|head| {
            self.call_args(head)
                .iter()
                .any(|arg| self.render_arg(*arg) == key)
        })
    }

    /// The head calls of the public clauses of `name/arity` — `Merge`'s
    /// `def_clause?/3` selection over `Source.def_clauses/1`.
    fn def_clauses(&self, name: &str, arity: usize) -> Vec<Node<'_>> {
        self.body()
            .into_iter()
            .filter(|child| self.def_clause_matches(*child, name, arity))
            .filter_map(|child| self.def_head_node(child))
            .collect()
    }

    /// True when the body child is a public clause of `name/arity` —
    /// `Merge.def_clause?/3` plus the `head_match?` name/arity test.
    fn def_clause_matches(&self, child: Node<'_>, name: &str, arity: usize) -> bool {
        self.call_target(child)
            .is_some_and(|target| target == "def")
            && self.def_head_node(child).is_some_and(|head| {
                self.def_head_of(head)
                    .is_some_and(|(n, a)| n == name && a == arity)
            })
    }

    /// The insert offset after the last clause of `name/arity` (keeps clause
    /// groups together), else at the end of the body — `Merge.after_def/2`'s
    /// `after_clauses_index/2`.
    pub fn insert_offset_after_def(&self, name: &str, arity: usize) -> Option<usize> {
        let block = do_block(self.module_call()?)?;
        let children = significant(block);
        let index = match (0..children.len())
            .rev()
            .find(|i| self.def_clause_matches(children[*i], name, arity))
        {
            Some(i) => i + 1,
            None => children.len(),
        };
        Some(self.offset_in_body(&children, index, block))
    }

    /// The keyword pairs of every entry of `macro_name` whose first argument
    /// renders to `key` — `Source.entry_kws/3`, the stale comparison's read.
    pub fn entry_kws(&self, macro_name: &str, key: &str) -> Vec<(String, String)> {
        self.calls(macro_name)
            .iter()
            .filter(|e| e.first_key() == key)
            .flat_map(|e| e.pairs())
            .collect()
    }

    // ---------------------------------------------------------- placement

    /// The insert offset for a head directive of `rank`.
    /// `alias_sort_key` selects the alphabetical position inside the alias
    /// block — `Merge.head/1` and `Merge.alias_of/1`.
    pub fn insert_offset_head(&self, rank: Rank, alias_sort_key: Option<&str>) -> Option<usize> {
        let block = do_block(self.module_call()?)?;
        let children = significant(block);
        let boundary = self.boundary_index(&children);
        let target = (0..boundary).find(|i| {
            let child = children[*i];
            let Some(existing) = self.child_rank(child) else {
                return false;
            };
            match (existing, alias_sort_key) {
                (Rank::Alias, Some(key)) => self
                    .call_args(child)
                    .first()
                    .is_some_and(|arg| self.render_arg(*arg).as_str() > key),
                _ => rank_ord(existing) > rank_ord(rank),
            }
        });
        let index = target.unwrap_or(boundary);
        Some(self.offset_in_body(&children, index, block))
    }

    /// The insert offset at the very end of the module body — `body_end/0`.
    pub fn insert_offset_body_end(&self) -> Option<usize> {
        let block = do_block(self.module_call()?)?;
        let children = significant(block);
        Some(self.offset_in_body(&children, children.len(), block))
    }

    /// The insert offset after the last top-level `describe`, else before
    /// the first `defp`, else at the end of the body — the index of
    /// `Merge.describe/0` (`after_describe_index/1` plus the
    /// `before_defp_index/1` fallback). Test files keep describe blocks
    /// together.
    pub fn insert_offset_after_describe(&self) -> Option<usize> {
        let block = do_block(self.module_call()?)?;
        let children = significant(block);
        let last_describe = (0..children.len()).rev().find(|i| {
            !is_remote(children[*i])
                && self
                    .call_target(children[*i])
                    .is_some_and(|name| name == "describe")
        });
        let index = match last_describe {
            Some(i) => i + 1,
            None => self.before_helpers_index(&children),
        };
        Some(self.offset_in_body(&children, index, block))
    }

    /// The insert offset before the first `defp` group (public API above
    /// private helpers), else at the end of the body — `Merge.before_helpers/0`
    /// and its `before_defp_index/1`.
    pub fn insert_offset_before_helpers(&self) -> Option<usize> {
        let block = do_block(self.module_call()?)?;
        let children = significant(block);
        let index = self.before_helpers_index(&children);
        Some(self.offset_in_body(&children, index, block))
    }

    /// The index of the first top-level `defp`, else the end of the body —
    /// `Merge.before_defp_index/1`, shared by the `before_helpers` placement
    /// and the `describe` fallback.
    fn before_helpers_index(&self, children: &[Node<'_>]) -> usize {
        children
            .iter()
            .position(|child| {
                !is_remote(*child) && self.call_target(*child).is_some_and(|name| name == "defp")
            })
            .unwrap_or(children.len())
    }

    /// The insert offset at the directive boundary, above the code —
    /// the materialization spot of `inside_block`'s wrapper path.
    pub fn insert_offset_after_directives(&self) -> Option<usize> {
        let block = do_block(self.module_call()?)?;
        let children = significant(block);
        let boundary = self.boundary_index(&children);
        Some(self.offset_in_body(&children, boundary, block))
    }

    /// The insert offset after the last top-level local call to
    /// `macro_name` whose rendered first argument satisfies `predicate` —
    /// `Merge.after_macro/3` with its `after_entry/3` scan. `None` when
    /// nothing matches; the caller then applies the fallback placement.
    pub fn insert_offset_after_macro(
        &self,
        macro_name: &str,
        predicate: &crate::plan::MacroPredicate,
    ) -> Option<usize> {
        self.insert_offset_after(macro_name, None, predicate)
    }

    /// The insert offset after the last top-level local call to
    /// `macro_name` whose keyword argument `key` renders to a value
    /// satisfying `predicate` — `Merge.after_macro_kw/4`. An absent keyword
    /// renders `nil` there and never matches an `Eq`.
    pub fn insert_offset_after_macro_kw(
        &self,
        macro_name: &str,
        key: &str,
        predicate: &crate::plan::MacroPredicate,
    ) -> Option<usize> {
        self.insert_offset_after(macro_name, Some(key), predicate)
    }

    /// The shared scan of the two `after_macro` factories: the last
    /// top-level local call of `macro_name` whose matched slot satisfies
    /// the predicate, inserted after it. `Merge.after_entry/3` walks the
    /// body's top-level expressions only — never nested blocks — and the
    /// fallback (if any) is the caller's decision.
    fn insert_offset_after(
        &self,
        macro_name: &str,
        keyword: Option<&str>,
        predicate: &crate::plan::MacroPredicate,
    ) -> Option<usize> {
        use crate::plan::MacroPredicate;
        let block = do_block(self.module_call()?)?;
        let children = significant(block);
        let last = (0..children.len()).rev().find(|i| {
            let child = children[*i];
            if !self
                .call_target(child)
                .is_some_and(|name| name == macro_name)
                || is_remote(child)
            {
                return false;
            }
            match predicate {
                MacroPredicate::Any => true,
                MacroPredicate::Eq(expected) => {
                    let entry = Entry {
                        node: child,
                        args: self.call_args(child),
                        file: self,
                    };
                    match keyword {
                        // `Merge.first_rendered/1` of an argless call
                        // renders `""` — the oracle compares the rendered
                        // text the same way
                        None => entry.first_key() == *expected,
                        // `kw_rendered/2` answers nil for an absent
                        // keyword and `value == expected` is then false
                        Some(key) => entry.kw(key).is_some_and(|v| v == *expected),
                    }
                }
            }
        })?;
        Some(self.offset_in_body(&children, last + 1, block))
    }

    /// The insert offset inside the first top-level call to `macro_name`
    /// that carries a `do` block, before the trailing run of
    /// `before_trailing` calls — `Merge.inside/3`. `None` when the call or
    /// its block does not exist (blocked; the wrapper case is decided by
    /// the caller, which then uses `insert_offset_after_directives`).
    pub fn insert_offset_inside(
        &self,
        macro_name: &str,
        before_trailing: Option<&str>,
    ) -> Option<usize> {
        let block = do_block(self.module_call()?)?;
        let call = significant(block).into_iter().find(|child| {
            self.call_target(*child)
                .is_some_and(|name| name == macro_name)
                && !is_remote(*child)
        })?;
        let inner = do_block(call)?;
        let body = significant(inner);
        let index = match before_trailing {
            Some(trailing) => {
                let mut run = body.len();
                while run > 0
                    && self
                        .call_target(body[run - 1])
                        .is_some_and(|name| name == trailing)
                {
                    run -= 1;
                }
                run
            }
            None => body.len(),
        };
        Some(self.offset_in_body(&body, index, inner))
    }

    /// `Source.deepest_scope/2` — the deepest scope of `scope_paths` that
    /// exists, as its byte range and the number of chain levels it matched.
    /// The chain walks inward: a level that is missing ends the walk, and no
    /// match at all answers `None`.
    pub fn deepest_scope(&self, scope_paths: &[String]) -> Option<(usize, usize, usize)> {
        let scopes = self.calls("scope");
        let mut best: Option<(usize, usize, usize)> = None;
        let mut lo = 0usize;
        let mut hi = usize::MAX;
        let mut depth = 0usize;
        for path in scope_paths {
            let found = scopes.iter().find(|scope| {
                &scope.first_key() == path && scope.start() > lo && scope.end() < hi
            })?;
            lo = found.start();
            hi = found.end();
            depth += 1;
            best = Some((found.start(), found.end(), depth));
        }
        best
    }

    /// True when a route (`verb` macro + action atom, e.g. `":create_widget"`)
    /// exists inside the scope chain of path strings — `Source.route_present?/4`.
    /// Routes are identified by action because paths like `"/"` collide
    /// across scopes.
    pub fn route_present(&self, verb: &str, action_key: &str, scope_paths: &[String]) -> bool {
        let Some((start, end, _depth)) = self.deepest_scope(scope_paths) else {
            return false;
        };
        self.calls(verb).iter().any(|entry| {
            entry.start() > start && entry.start() < end && entry.action_key() == action_key
        })
    }

    /// `Merge.scope/1`'s `deepest_scope/2` plus `append_at_depth/4` — the
    /// insert offset at the end of the body of the deepest existing scope of
    /// `chain`, and how many levels matched. `None` when even the outermost
    /// scope is missing (blocked).
    pub fn insert_offset_scope(&self, chain: &[crate::plan::ScopeLevel]) -> Option<(usize, usize)> {
        let mut block = do_block(self.module_call()?)?;
        let mut depth = 0usize;
        for (path, _alias) in chain {
            let found = significant(block).into_iter().find(|child| {
                !is_remote(*child)
                    && self.call_target(*child).is_some_and(|name| name == "scope")
                    && self.first_rendered(*child) == *path
            });
            match found {
                Some(scope) => {
                    depth += 1;
                    block = do_block(scope)?;
                }
                None => break,
            }
        }
        if depth == 0 {
            return None;
        }
        let children = significant(block);
        Some((self.offset_in_body(&children, children.len(), block), depth))
    }

    /// `Merge.first_rendered/1` of a call node.
    fn first_rendered(&self, node: Node<'_>) -> String {
        self.call_args(node)
            .first()
            .map(|arg| self.render_arg(*arg))
            .unwrap_or_default()
    }

    /// Offset at an insert index inside a block body: before the item at
    /// `index`, or before the block's `end` when appending. Comments
    /// leading the item stay attached above the insert.
    fn offset_in_body(&self, body: &[Node<'_>], index: usize, block: Node<'_>) -> usize {
        if index < body.len() {
            self.line_start_attached(body[index])
        } else {
            let end = block_end_token(block).unwrap_or_else(|| block.end_byte());
            self.line_start_at(end)
        }
    }

    /// Line start of `node`, walking back over its own attached comments.
    fn line_start_attached(&self, node: Node<'_>) -> usize {
        let mut offset = self.line_start_at(node.start_byte());
        let mut prev = node.prev_sibling();
        while let Some(p) = prev {
            if p.kind() != "comment" {
                break;
            }
            offset = self.line_start_at(p.start_byte());
            prev = p.prev_sibling();
        }
        offset
    }

    fn line_start_at(&self, byte: usize) -> usize {
        let floor = byte.min(self.text.len());
        match self.text[..floor].rfind('\n') {
            Some(nl) => nl + 1,
            None => 0,
        }
    }

    // ------------------------------------------------------------- splice

    /// Insert `insert` at `offset`, keeping every other byte — the write
    /// half of the splice verdict.
    pub fn splice(&self, offset: usize, insert: &str) -> String {
        let mut out = String::with_capacity(self.text.len() + insert.len());
        out.push_str(&self.text[..offset]);
        out.push_str(insert);
        out.push_str(&self.text[offset..]);
        out
    }

    /// True when the dotted `module` occurs anywhere in the file — supervisor
    /// children are listed by full module name (or aliased), so a text hit
    /// counts. `Source.has_child?/2`.
    pub fn has_child(&self, module: &str) -> bool {
        self.text.contains(module)
    }

    /// The current text, for a run without any write.
    pub fn text(&self) -> &str {
        &self.text
    }

    /// The file text with the first `children = [...]` binding replaced by an
    /// inline list of its existing elements plus `unit_text` — the faithful
    /// splice form of `Merge.children_list/0`'s `Zipper.replace(parent,
    /// {:=, meta, [lhs, list ++ ns]})`, which reprints the whole assignment
    /// with no source newlines. `None` when the assignment or its list is
    /// missing (blocked).
    pub fn children_list_replace(&self, unit_text: &str) -> Option<String> {
        let root = self.tree.as_ref()?.root_node();
        let list = find_children_list(root, &self.text)?;
        let binding = list
            .parent()
            .filter(|node| node.kind() == "binary_operator")?;
        let lhs = self.source_text(binding.named_child(0)?).trim().to_string();
        let mut cursor = list.walk();
        let mut items: Vec<String> = list
            .named_children(&mut cursor)
            .map(|element| self.source_text(element).trim().to_string())
            .collect();
        items.push(unit_text.trim().to_string());
        let replacement = format!("{lhs} = [{}]", items.join(", "));
        let start = binding.start_byte();
        let end = binding.end_byte();
        Some(format!(
            "{}{replacement}{}",
            &self.text[..start],
            &self.text[end..]
        ))
    }

    // ------------------------------------------------------------- keys

    /// Render a call argument as an entry key — `Source.render_arg/1`.
    pub fn render_arg(&self, node: Node<'_>) -> String {
        let text = self.source_text(node);
        if node.kind() == "binary_operator" {
            // `{:=, _, [left | _]} -> render_arg(left)` and
            // `{:when, _, [head | _]} -> render_arg(head)` — a binding or a
            // guard renders as its left-hand shape; every other operator
            // keeps its normalized `Macro.to_string` text
            if matches!(operator_token(node).as_str(), "=" | "when")
                && let Some(left) = node.named_child(0)
            {
                return self.render_arg(left);
            }
            return normalize(text);
        }
        match node.kind() {
            "atom" | "identifier" | "alias" => text.trim().to_string(),
            "string" | "charlist" => self.unquote(text),
            "tuple" | "map" if is_struct_pattern(text) => {
                // %Event{} patterns render as `Event{}`
                let inner = text
                    .trim()
                    .trim_start_matches('%')
                    .trim_end_matches("{}")
                    .trim();
                format!("{inner}{{}}")
            }
            _ => normalize(text),
        }
    }

    /// The exact unquoted content of a string literal — `literal_text/1`.
    pub fn literal_text(&self, node: Node<'_>) -> Option<&str> {
        if node.kind() == "string" {
            Some(self.string_content(node))
        } else {
            None
        }
    }

    fn string_content(&self, node: Node<'_>) -> &str {
        let t = self.source_text(node).trim();
        if t.starts_with("\"\"\"") && t.ends_with("\"\"\"") && t.len() >= 6 {
            return t[3..t.len() - 3].trim();
        }
        if t.starts_with('"') && t.ends_with('"') && t.len() >= 2 {
            return &t[1..t.len() - 1];
        }
        t
    }

    fn unquote(&self, text: &str) -> String {
        let trimmed = text.trim();
        if trimmed.starts_with("\"\"\"") && trimmed.ends_with("\"\"\"") && trimmed.len() >= 6 {
            return trimmed[3..trimmed.len() - 3].trim().to_string();
        }
        if trimmed.len() >= 2 {
            let chars: Vec<char> = trimmed.chars().collect();
            let (first, last) = (chars[0], chars[chars.len() - 1]);
            if (first == '"' && last == '"') || (first == '\'' && last == '\'') {
                return trimmed[1..trimmed.len() - 1].to_string();
            }
        }
        normalize(trimmed)
    }

    /// The name a `keyword` node carries (`type: ` → `type`).
    fn keyword_name(&self, node: Node<'_>) -> String {
        self.source_text(node)
            .trim()
            .trim_end_matches(':')
            .to_string()
    }

    // ----------------------------------------------------------------- bits

    fn module_call(&self) -> Option<Node<'_>> {
        let root = self.tree.as_ref().map(Tree::root_node)?;
        let mut cursor = root.walk();
        root.named_children(&mut cursor).find(|child| {
            child.kind() == "call"
                && self
                    .call_target(*child)
                    .is_some_and(|name| name == "defmodule")
        })
    }

    /// The statements of the module body, comments and `do`/`end` excluded.
    fn body(&self) -> Vec<Node<'_>> {
        match self.module_call().and_then(do_block) {
            Some(block) => significant(block),
            None => Vec::new(),
        }
    }

    /// First body index that is code — the end of the directive block
    /// (`rank_index`'s boundary).
    fn boundary_index(&self, children: &[Node<'_>]) -> usize {
        children
            .iter()
            .position(|child| self.child_rank(*child).is_none())
            .unwrap_or(children.len())
    }

    fn child_rank(&self, node: Node<'_>) -> Option<Rank> {
        if let Some(name) = self.attr_name(node) {
            return Some(if name == "moduledoc" {
                Rank::Moduledoc
            } else {
                Rank::Attribute
            });
        }
        if is_remote(node) {
            return None;
        }
        match self.call_target(node)?.as_str() {
            "use" => Some(Rank::Use),
            "import" => Some(Rank::Import),
            "alias" => Some(Rank::Alias),
            "require" => Some(Rank::Require),
            _ => None,
        }
    }

    fn attr_name(&self, node: Node<'_>) -> Option<String> {
        let call = self.attr_call(node)?;
        self.call_target(call)
    }

    /// The call under a leading `@` token — attributes are `unary_operator`
    /// nodes whose children are the `@` token plus the call.
    fn attr_call<'a>(&self, node: Node<'a>) -> Option<Node<'a>> {
        if node.kind() != "unary_operator" {
            return None;
        }
        let mut cursor = node.walk();
        let mut children = node.children(&mut cursor);
        let at = children.next()?;
        (at.kind() == "@")
            .then(|| children.find(|child| child.kind() == "call"))
            .flatten()
    }

    fn attr_values<'a>(&self, node: Node<'a>) -> Vec<Node<'a>> {
        let Some(call) = self.attr_call(node) else {
            return Vec::new();
        };
        let mut out = Vec::new();
        for arg in self.call_args(call) {
            match arg.kind() {
                "alias" | "string" => out.push(arg),
                _ => {
                    let mut cursor = arg.walk();
                    for child in arg.named_children(&mut cursor) {
                        if matches!(child.kind(), "alias" | "string") {
                            out.push(child);
                        }
                    }
                }
            }
        }
        out
    }

    /// The local call target name; `None` for remote calls and other shapes.
    fn call_target(&self, node: Node<'_>) -> Option<String> {
        if node.kind() != "call" {
            return None;
        }
        let first = node.named_child(0)?;
        if first.kind() == "identifier" {
            Some(self.source_text(first).to_string())
        } else {
            None
        }
    }

    /// The argument nodes of a call — atoms, strings, aliases, lists, …
    fn call_args<'a>(&self, node: Node<'a>) -> Vec<Node<'a>> {
        let mut out = Vec::new();
        let mut cursor = node.walk();
        for child in node.children(&mut cursor) {
            if child.kind() == "arguments" {
                let mut inner = child.walk();
                out.extend(child.named_children(&mut inner));
            }
        }
        out
    }

    /// The name and arity of a `def` head — `Merge.head_match?/3`.
    fn def_head(&self, def_call: Node<'_>) -> Option<(String, usize)> {
        let head = self.call_args(def_call).into_iter().next()?;
        self.def_head_of(head)
    }

    /// The head call node of a `def` clause, guard unwrapped — the head
    /// expression `Source.def_head/1` reads as `{name, _, args}`.
    fn def_head_node<'a>(&self, def_call: Node<'a>) -> Option<Node<'a>> {
        let head = self.call_args(def_call).into_iter().next()?;
        Some(self.unwrap_when(head))
    }

    /// Unwrap `def foo(...) when guard` — the grammar wraps the head call in
    /// a `binary_operator` with a `when` token; Elixir's AST wraps it in
    /// `{:when, _, [plain | _]}` and `def_head` recurses on `plain`.
    fn unwrap_when<'a>(&self, head: Node<'a>) -> Node<'a> {
        if head.kind() == "binary_operator"
            && operator_token(head) == "when"
            && let Some(left) = head.named_child(0)
        {
            return self.unwrap_when(left);
        }
        head
    }

    fn def_head_of(&self, head: Node<'_>) -> Option<(String, usize)> {
        match head.kind() {
            "call" => {
                let name = head.named_child(0).filter(|n| n.kind() == "identifier")?;
                let arity = {
                    let mut cursor = head.walk();
                    head.children(&mut cursor)
                        .find(|child| child.kind() == "arguments")
                        .map(|a| {
                            let mut inner = a.walk();
                            a.named_children(&mut inner).count()
                        })
                        .unwrap_or(0)
                };
                Some((self.source_text(name).to_string(), arity))
            }
            "identifier" => Some((self.source_text(head).to_string(), 0)),
            "binary_operator" => {
                // `def foo when guard` — the head is the left side, the
                // `{:when, _meta, [plain | _]}` case of `Source.def_head/1`
                if operator_token(head) == "when" {
                    self.def_head_of(head.named_child(0)?)
                } else {
                    None
                }
            }
            _ => None,
        }
    }
}

/// Debug helpers used by probe tests: the block's `end` token offset.
fn block_end_token(block: Node<'_>) -> Option<usize> {
    let mut cursor = block.walk();
    block
        .children(&mut cursor)
        .find(|child| child.kind() == "end")
        .map(|node| node.start_byte())
}

/// The `list` node on the right of the first `children = [...]` binding at any
/// depth — `Merge.children_list/0`'s `Zipper.find(&match?({:children, _, nil}))`
/// plus the `{:=, _, [lhs, rhs]}` parent check and `unwrap_list/1`.
fn find_children_list<'a>(node: Node<'a>, text: &str) -> Option<Node<'a>> {
    if node.kind() == "binary_operator" && operator_token(node) == "=" {
        let mut cursor = node.walk();
        let operands: Vec<Node<'a>> = node.named_children(&mut cursor).collect();
        if let (Some(lhs), Some(rhs)) = (operands.first(), operands.get(1))
            && text[lhs.byte_range()].trim() == "children"
            && rhs.kind() == "list"
        {
            return Some(*rhs);
        }
    }
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        if let Some(list) = find_children_list(child, text) {
            return Some(list);
        }
    }
    None
}

/// The operator token kind of a `binary_operator` node — `"="` for a
/// binding, `"when"` for a guard, `"|>"` for a pipe, and so on. `None` when
/// the node has no operator child.
fn operator_token(node: Node<'_>) -> String {
    let mut cursor = node.walk();
    node.children(&mut cursor)
        .find(|child| !child.is_named())
        .map(|child| child.kind().to_string())
        .unwrap_or_default()
}

/// `%Alias{}` — a struct match pattern, not a plain map literal.
fn is_struct_pattern(text: &str) -> bool {
    let t = text.trim();
    let Some(inner) = t.strip_prefix('%').and_then(|r| r.strip_suffix("{}")) else {
        return false;
    };
    let inner = inner.trim();
    !inner.is_empty()
        && inner.starts_with(char::is_uppercase)
        && inner
            .chars()
            .all(|c| c.is_alphanumeric() || c == '.' || c == '_')
}

fn normalize(text: &str) -> String {
    let mut out = String::new();
    let mut last_whitespace = false;
    for c in text.trim().chars() {
        if c.is_whitespace() {
            last_whitespace = true;
            continue;
        }
        if last_whitespace && !out.is_empty() {
            out.push(' ');
        }
        last_whitespace = false;
        out.push(c);
    }
    out
}

fn is_remote(node: Node<'_>) -> bool {
    node.kind() == "call"
        && node
            .named_child(0)
            .is_some_and(|first| first.kind() != "identifier")
}

fn do_block(call: Node<'_>) -> Option<Node<'_>> {
    let mut cursor = call.walk();
    call.children(&mut cursor)
        .find(|child| child.kind() == "do_block")
}

/// Block children that are statements: no `do`/`end` keywords, no comments.
fn significant(block: Node<'_>) -> Vec<Node<'_>> {
    let mut cursor = block.walk();
    block
        .named_children(&mut cursor)
        .filter(|child| !matches!(child.kind(), "do" | "end" | "comment"))
        .collect()
}

fn rank_ord(rank: Rank) -> u8 {
    rank as u8
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A file as the read-model blueprint meets it after creation: the
    /// shape the oracle (Elixir tool) produces, hand-adopted here as the
    /// expectation baseline.
    const READ_MODEL: &str = r#"defmodule Sportipedia.Catalog.Equipment.Widget.WidgetReadModel do
  @moduledoc """
  Represents a widget in the equipment.
  """
  use TypedEctoSchema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @schema_prefix "catalog"

  typed_schema "widgets" do
    field :title, :string
    field :weight, :float

    timestamps()
  end

  def insert_changeset(read_model, attrs) do
    read_model
    |> Ecto.Changeset.cast(attrs, [:id, :title])
    |> validate_required([:title])
    |> unique_constraint(:slug, name: :widget_slug_index)
  end
end
"#;

    #[test]
    fn module_name_is_dotted_alias() {
        let f = ElixirFile::parse(READ_MODEL);
        assert!(f.parsed());
        assert_eq!(
            f.module_name().as_deref(),
            Some("Sportipedia.Catalog.Equipment.Widget.WidgetReadModel")
        );
    }

    #[test]
    fn directives_are_present() {
        let f = ElixirFile::parse(READ_MODEL);
        assert!(f.has_moduledoc());
        assert!(f.has_use("TypedEctoSchema"));
        assert!(!f.has_use("Ecto.Schema"));
        assert!(f.has_import("Ecto.Changeset"));
        assert!(f.has_attribute("primary_key"));
        assert!(f.has_attribute("timestamps_opts"));
        assert!(f.has_attribute("schema_prefix"));
        assert!(!f.has_attribute("nonexistent"));
    }

    #[test]
    fn behaviour_and_derive_read_module_names() {
        let src =
            "defmodule M do\n  @behaviour Sportipedia.Command\n  @derive [Jason.Encoder]\nend\n";
        let f = ElixirFile::parse(src);
        assert!(f.attr_names("behaviour", "Sportipedia.Command"));
        assert!(!f.attr_names("behaviour", "Sportipedia.Query"));
        assert!(f.attr_names("derive", "Jason.Encoder"));
    }

    #[test]
    fn entry_search_is_local_and_block_scoped() {
        let f = ElixirFile::parse(READ_MODEL);
        assert!(f.has_entry("field", ":title"));
        assert!(f.has_entry("field", ":weight"));
        assert!(!f.has_entry("field", ":slug"));
        // the walk stops at def bodies, exactly like `Source.calls/2`:
        // cast/validate_required live inside insert_changeset
        assert_eq!(f.calls("cast").len(), 0);
        assert_eq!(f.calls("validate_required").len(), 0);
        assert_eq!(f.calls("field").len(), 2);
    }

    #[test]
    fn entry_key_identity_matches_render_arg_rules() {
        let src = "defmodule M do\n  alias Sportipedia.Catalog\n  field :title, :string\n  dispatch My.Mod, :act\n  project %WidgetArchived{}, :md, fn s, e -> s end\n  describe \"command archive-widget\" do\n  end\nend\n";
        let f = ElixirFile::parse(src);
        assert!(f.has_alias("Sportipedia.Catalog"));
        assert!(f.has_entry("field", ":title"));
        // remote alias in a dispatch target renders dotted (Elixir `My.Mod`)
        let dispatches = f.calls("dispatch");
        assert_eq!(dispatches[0].first_key(), "My.Mod");
        // %Event{} patterns render as `Event{}`
        let projects = f.calls("project");
        assert_eq!(projects[0].first_key(), "WidgetArchived{}");
        // describe subject is the exact unquoted string
        assert!(f.has_describe("command archive-widget"));
        assert!(!f.has_describe("command archive widget"));
    }

    #[test]
    fn validates_pairs_keep_every_key_in_source_order() {
        let src = "defmodule M do\n  validates :slug, presence: true, by: [function: &UniqueSlug.validate/2], by: [function: &OtherRule.validate/2]\nend\n";
        let f = ElixirFile::parse(src);
        let pairs = f.entry_kws("validates", ":slug");
        assert_eq!(pairs.len(), 3);
        assert_eq!(pairs[0], ("presence".to_string(), "true".to_string()));
        // rendered list values normalize whitespace, keep the capture text
        assert!(pairs[1].1.contains("&UniqueSlug.validate/2"));
        assert!(pairs[2].1.contains("&OtherRule.validate/2"));
    }

    #[test]
    fn defs_match_name_and_arity() {
        let src = "defmodule M do\n  def go do\n    :ok\n  end\n\n  def go(x), do: x\n\n  defp help(x, y) do\n    {x, y}\n  end\nend\n";
        let f = ElixirFile::parse(src);
        assert!(f.has_def("go", 0));
        assert!(f.has_def("go", 1));
        assert!(!f.has_def("go", 2));
        // `def_clauses` reads public defs only — a defp is not a def
        assert!(!f.has_def("help", 2));
    }

    // ---------------------------------------------------------- placement

    #[test]
    fn head_insertions_land_in_rank_order() {
        // the empty shell of creation
        let src = "defmodule M do\nend\n";
        let f = ElixirFile::parse(src);
        // the `end` token starts its own line at 15
        assert_eq!(f.insert_offset_head(Rank::Moduledoc, None), Some(15));
        assert_eq!(f.insert_offset_body_end(), Some(15));
    }

    #[test]
    fn head_insert_above_first_higher_rank() {
        let f = ElixirFile::parse(READ_MODEL);
        // a `use` joins above the `import` already present
        let offset = f.insert_offset_head(Rank::Use, None).unwrap();
        let next = f.splice(offset, "use My.Use\n");
        assert!(next.contains("use My.Use\n  import Ecto.Changeset"));
        assert!(!next.contains("import Ecto.Changeset\n  use My.Use"));
    }

    /// The three land in the given relative order in the text.
    fn order(next: &str, a: &str, b: &str, c: &str) -> bool {
        let (ia, ib, ic) = (next.find(a), next.find(b), next.find(c));
        match (ia, ib, ic) {
            (Some(ia), Some(ib), Some(ic)) => ia < ib && ib < ic,
            _ => false,
        }
    }

    #[test]
    fn alias_insert_is_alphabetical() {
        let src = "defmodule M do\n  alias Alpha\n  alias Gamma\nend\n";
        let f = ElixirFile::parse(src);
        let offset = f.insert_offset_head(Rank::Alias, Some("Beta")).unwrap();
        let next = f.splice(offset, "alias Beta\n");
        assert!(order(&next, "alias Alpha", "alias Beta", "alias Gamma"));
    }

    #[test]
    fn inside_lands_before_the_trailing_run() {
        let f = ElixirFile::parse(READ_MODEL);
        let offset = f
            .insert_offset_inside("typed_schema", Some("timestamps"))
            .unwrap();
        let next = f.splice(offset, "field :slug, :string\n");
        assert!(order(&next, "field :weight", "field :slug", "timestamps()"));
        // the splice never touches bytes outside the insert
        assert!(ElixirFile::parse(&next).parsed());
    }

    #[test]
    fn inside_is_blocked_without_the_host_call() {
        let src = "defmodule M do\n  use Foo\nend\n";
        let f = ElixirFile::parse(src);
        assert_eq!(
            f.insert_offset_inside("typed_schema", Some("timestamps")),
            None
        );
        // the wrapper materialization lands at the directive boundary
        let offset = f.insert_offset_after_directives().unwrap();
        let next = f.splice(offset, "typed_schema \"w\" do\nend\n");
        assert!(ElixirFile::parse(&next).parsed());
    }

    #[test]
    fn body_end_appends_before_module_end() {
        let f = ElixirFile::parse(READ_MODEL);
        let offset = f.insert_offset_body_end().unwrap();
        let next = f.splice(
            offset,
            "def update_changeset(read_model, attrs), do: attrs\n",
        );
        let re = ElixirFile::parse(&next);
        assert!(re.parsed());
        assert!(re.has_def("update_changeset", 2));
    }

    #[test]
    fn after_describe_appends_past_the_last_describe_block() {
        let src = "defmodule MTest do\n  use ExUnit.Case\n\n  describe \"Event\" do\n    test \"a\" do\n    end\n  end\n\n  describe \"Aggregate\" do\n    test \"b\" do\n    end\n  end\n\n  defp helper do\n    :ok\n  end\nend\n";
        let f = ElixirFile::parse(src);
        let offset = f.insert_offset_after_describe().unwrap();
        let next = f.splice(offset, "describe \"Projector\" do\nend\n");
        // the new block joins the describe run, above the private helper
        assert!(order(
            &next,
            "describe \"Aggregate\"",
            "describe \"Projector\"",
            "defp helper"
        ));
        assert!(ElixirFile::parse(&next).parsed());
    }

    #[test]
    fn after_describe_falls_back_before_helpers_then_body_end() {
        // no describe blocks: the insert lands before the first defp
        let src = "defmodule MTest do\n  defp helper do\n    :ok\n  end\nend\n";
        let f = ElixirFile::parse(src);
        let offset = f.insert_offset_after_describe().unwrap();
        let next = f.splice(offset, "describe \"Event\" do\nend\n");
        assert!(next.contains("describe \"Event\" do\nend\n  defp helper"));

        // nothing but directives: the append position is the body end
        let src = "defmodule MTest do\n  use ExUnit.Case\nend\n";
        let f = ElixirFile::parse(src);
        let offset = f.insert_offset_after_describe().unwrap();
        let next = f.splice(offset, "describe \"Event\" do\nend\n");
        assert!(next.contains("use ExUnit.Case\ndescribe \"Event\" do\nend\nend"));
    }

    // ------------------------------------------------------------ after_macro

    #[test]
    fn after_macro_lands_after_the_last_matching_entry() {
        let src = "defmodule R do\n  middleware Identity\n\n  identify GadgetAggregate, by: :id\n\n  dispatch CreateGadget, to: CreateGadgetHandler, aggregate: GadgetAggregate\nend\n";
        let f = ElixirFile::parse(src);
        // `Merge.after_macro(:dispatch, fn _ -> true end, ...)`: any match
        let offset = f
            .insert_offset_after_macro("dispatch", &crate::plan::MacroPredicate::Any)
            .unwrap();
        let next = f.splice(offset, "dispatch NoteWidget, to: NoteWidgetHandler\n");
        assert!(
            next.contains("dispatch CreateGadget, to: CreateGadgetHandler, aggregate: GadgetAggregate\ndispatch NoteWidget"),
            "the new dispatch follows the last one:\n{next}"
        );
        // a first-argument Eq only matches that text
        assert!(
            f.insert_offset_after_macro(
                "identify",
                &crate::plan::MacroPredicate::Eq("WidgetAggregate".into())
            )
            .is_none(),
            "the gadget identify does not answer to the widget name"
        );
        // nothing matches → the caller's fallback decides
        assert!(
            f.insert_offset_after_macro("scope", &crate::plan::MacroPredicate::Any)
                .is_none()
        );
    }

    #[test]
    fn after_macro_kw_matches_the_keyword_value_only() {
        let src = "defmodule R do\n  dispatch CreateGadget, to: CreateGadgetHandler, aggregate: GadgetAggregate\n\n  dispatch ArchiveWidget, to: ArchiveWidgetHandler, aggregate: WidgetAggregate\n\n  dispatch NoteWidget, to: NoteWidgetHandler, aggregate: WidgetAggregate\nend\n";
        let f = ElixirFile::parse(src);
        // `Merge.after_macro_kw(:dispatch, :aggregate, == WidgetAggregate)`:
        // the insert goes after the last line of the WIDGET cluster, not
        // after the whole dispatch run
        let offset = f
            .insert_offset_after_macro_kw(
                "dispatch",
                "aggregate",
                &crate::plan::MacroPredicate::Eq("WidgetAggregate".into()),
            )
            .unwrap();
        let next = f.splice(
            offset,
            "dispatch EditWidget, to: EditWidgetHandler, aggregate: WidgetAggregate\n",
        );
        assert!(
            next.contains(
                "dispatch NoteWidget, to: NoteWidgetHandler, aggregate: WidgetAggregate\ndispatch EditWidget, to: EditWidgetHandler, aggregate: WidgetAggregate\nend"
            ),
            "the new dispatch joins the last line of its aggregate's cluster:\n{next}"
        );
        // an entry without the keyword never matches an Eq
        let no_kw = ElixirFile::parse("defmodule R do\n  dispatch Bare\nend\n");
        assert!(
            no_kw
                .insert_offset_after_macro_kw(
                    "dispatch",
                    "aggregate",
                    &crate::plan::MacroPredicate::Eq("WidgetAggregate".into())
                )
                .is_none()
        );
    }

    #[test]
    fn after_macro_scans_top_level_entries_only() {
        // `Merge.after_entry/3` walks the body's expressions — a `dispatch`
        // hidden inside another call's block does not count
        let src = "defmodule R do\n  def build do\n    dispatch InsideDef\n  end\nend\n";
        let f = ElixirFile::parse(src);
        assert!(
            f.insert_offset_after_macro("dispatch", &crate::plan::MacroPredicate::Any)
                .is_none(),
            "the scan never enters function bodies"
        );
    }

    #[test]
    fn before_helpers_inserts_above_the_first_defp_else_appends() {
        // `Merge.before_helpers/0`: public defs land above the private helpers
        let src = "defmodule M do\n  def public do\n    :ok\n  end\n\n  defp helper(x) do\n    x\n  end\nend\n";
        let f = ElixirFile::parse(src);
        let offset = f.insert_offset_before_helpers().unwrap();
        let next = f.splice(offset, "def second_public do\n  :ok\nend\n");
        assert!(order(
            &next,
            "def public",
            "def second_public",
            "defp helper"
        ));
        assert!(ElixirFile::parse(&next).parsed());

        // no defp at all: the end of the body is the append position
        let src = "defmodule M do\n  def public do\n    :ok\n  end\nend\n";
        let f = ElixirFile::parse(src);
        let offset = f.insert_offset_before_helpers().unwrap();
        let next = f.splice(offset, "def second_public do\n  :ok\nend\n");
        assert!(next.contains("def second_public"));
        assert!(ElixirFile::parse(&next).parsed());
    }

    #[test]
    fn children_list_appends_and_collapses_a_multiline_list() {
        let src = "defmodule S do\n  def init(_arg) do\n    children = [\n      Sportipedia.Catalog\n    ]\n\n    Supervisor.init(children, strategy: :one_for_one)\n  end\nend\n";
        let f = ElixirFile::parse(src);
        let next = f
            .children_list_replace("Sportipedia.Catalog.Gadget.GadgetProjector")
            .expect("the children list exists");
        assert!(
            next.contains(
                "children = [Sportipedia.Catalog, Sportipedia.Catalog.Gadget.GadgetProjector]"
            ),
            "the list lands on one line, the reprint's shape:\n{next}"
        );
        let grown = ElixirFile::parse(&next);
        assert!(grown.parsed(), "{next}");
        assert!(grown.has_child("Sportipedia.Catalog.Gadget.GadgetProjector"));
    }

    #[test]
    fn children_list_fills_an_empty_list_and_blocks_without_one() {
        let empty = ElixirFile::parse(
            "defmodule S do\n  def init(_arg) do\n    children = []\n  end\nend\n",
        );
        let next = empty
            .children_list_replace("Sportipedia.Catalog.Gadget.GadgetProjector")
            .expect("the empty list is found");
        assert!(
            next.contains("children = [Sportipedia.Catalog.Gadget.GadgetProjector]"),
            "{next}"
        );
        assert!(ElixirFile::parse(&next).parsed(), "{next}");
        assert!(
            ElixirFile::parse("defmodule S do\nend\n")
                .children_list_replace("X")
                .is_none()
        );
    }

    #[test]
    fn splices_keep_human_bytes_untouched() {
        let f = ElixirFile::parse(READ_MODEL);
        let offset = f
            .insert_offset_inside("typed_schema", Some("timestamps"))
            .unwrap();
        let next = f.splice(offset, "field :slug, :string\n");
        // everything before and after the insert is byte-identical
        assert_eq!(&next[..offset], &READ_MODEL[..offset]);
        assert_eq!(
            &next[offset + "field :slug, :string\n".len()..],
            &READ_MODEL[offset..]
        );
    }
}
