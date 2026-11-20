//! The TypeScript file model. Parse a
//! file for reading (presence checks, placement offsets), and express
//! changes as **text splices**.
//!
//! Write-path verdict (README): sparch-typescript never reprints a human file. The
//! AST is used to decide *what exists* and *where new text goes*; existing
//! bytes are never re-rendered, so comments and quirks of hand-written code
//! survive by construction.

use oxc_allocator::Allocator;
use oxc_ast::ast::{Declaration, ImportDeclarationSpecifier, ModuleExportName, Program, Statement};
use oxc_parser::Parser;
use oxc_span::SourceType;

/// One `import ... from 'source'` statement, reduced to what merging needs.
#[derive(Clone, Debug)]
pub struct ImportInfo {
    pub source: String,
    pub type_only: bool,
    /// Specifier surface names: `default` for defaults, `*` for namespaces,
    /// the binding name otherwise (`a as b` contributes `b`).
    pub specifiers: Vec<String>,
    pub statement_end: u32,
    /// Byte offsets inside the braces, for splicing a new specifier;
    /// `None` for default/namespace imports.
    pub brace_open: Option<u32>,
    pub brace_close: Option<u32>,
}

pub struct TsFile {
    pub text: String,
    /// Every top-level declaration name — including the specifiers of
    /// `export { a } from './x'` barrels, which is what the barrel's
    /// presence checks read.
    pub declarations: Vec<String>,
    /// Byte spans of the declarable units (`--force` replacement ranges),
    /// keyed by name.
    pub declaration_spans: Vec<(String, u32, u32)>,
    pub imports: Vec<ImportInfo>,
    /// Byte offset just after the last import statement.
    pub after_last_import: u32,
}

impl TsFile {
    pub fn parse(path_hint: &str, text: String) -> Option<TsFile> {
        let allocator = Allocator::default();
        let source_type = SourceType::from_path(path_hint).unwrap_or_else(|_| SourceType::ts());
        let ret = Parser::new(&allocator, &text, source_type).parse();
        if ret.fatal_error {
            return None;
        }
        let collected = collect(&ret.program, &text);
        Some(TsFile {
            text,
            declarations: collected.declarations,
            declaration_spans: collected.declaration_spans,
            imports: collected.imports,
            after_last_import: collected.after_last_import,
        })
    }

    pub fn declares(&self, name: &str) -> bool {
        self.declarations.iter().any(|d| d == name)
    }

    pub fn declaration_span(&self, name: &str) -> Option<(u32, u32)> {
        self.declaration_spans
            .iter()
            .find(|(n, _, _)| n == name)
            .map(|(_, s, e)| (*s, *e))
    }

    /// `test('title'` presence for the ability-test blueprint.
    pub fn has_test(&self, title: &str) -> bool {
        self.text.contains(&format!("test('{title}'"))
            || self.text.contains(&format!("test(\"{title}\""))
    }

    pub fn import_for(&self, source: &str, type_only: bool) -> Option<&ImportInfo> {
        self.imports
            .iter()
            .find(|i| i.source == source && i.type_only == type_only)
    }

    pub fn imports_specifier(&self, source: &str, type_only: bool, specifier: &str) -> bool {
        self.import_for(source, type_only)
            .is_some_and(|i| i.specifiers.iter().any(|s| s == specifier))
    }
}

struct Collected {
    declarations: Vec<String>,
    declaration_spans: Vec<(String, u32, u32)>,
    imports: Vec<ImportInfo>,
    after_last_import: u32,
}

fn push_decl(
    declarations: &mut Vec<String>,
    spans: &mut Vec<(String, u32, u32)>,
    name: String,
    start: u32,
    end: u32,
) {
    declarations.push(name.clone());
    spans.push((name, start, end));
}

fn collect(program: &Program<'_>, text: &str) -> Collected {
    let mut declarations = Vec::new();
    let mut spans: Vec<(String, u32, u32)> = Vec::new();
    let mut imports = Vec::new();

    for statement in &program.body {
        match statement {
            Statement::ImportDeclaration(import) => {
                collect_import(text, import, &mut imports);
            }
            Statement::ExportDeclaration(export) => {
                let (start, end) = (export.span.start, export.span.end);
                collect_declaration(&export.declaration, &mut |name| {
                    push_decl(&mut declarations, &mut spans, name, start, end)
                });
            }
            Statement::ExportFromDeclaration(reexport) => {
                for specifier in &reexport.specifiers {
                    declarations.push(exported_name(&specifier.exported));
                }
            }
            Statement::ExportNamedDeclaration(named) => {
                for specifier in &named.specifiers {
                    declarations.push(exported_name(&specifier.exported));
                }
            }
            Statement::FunctionDeclaration(function) => {
                if let Some(ident) = &function.id {
                    push_decl(
                        &mut declarations,
                        &mut spans,
                        ident.name.to_string(),
                        function.span.start,
                        function.span.end,
                    );
                }
            }
            Statement::ClassDeclaration(class) => {
                if let Some(ident) = &class.id {
                    push_decl(
                        &mut declarations,
                        &mut spans,
                        ident.name.to_string(),
                        class.span.start,
                        class.span.end,
                    );
                }
            }
            Statement::VariableDeclaration(variables) => {
                for declarator in &variables.declarations {
                    for ident in declarator.id.get_binding_identifiers() {
                        push_decl(
                            &mut declarations,
                            &mut spans,
                            ident.name.to_string(),
                            variables.span.start,
                            variables.span.end,
                        );
                    }
                }
            }
            Statement::TSTypeAliasDeclaration(alias) => push_decl(
                &mut declarations,
                &mut spans,
                alias.id.name.to_string(),
                alias.span.start,
                alias.span.end,
            ),
            Statement::TSInterfaceDeclaration(interface) => push_decl(
                &mut declarations,
                &mut spans,
                interface.id.name.to_string(),
                interface.span.start,
                interface.span.end,
            ),
            Statement::TSEnumDeclaration(enum_decl) => push_decl(
                &mut declarations,
                &mut spans,
                enum_decl.id.name.to_string(),
                enum_decl.span.start,
                enum_decl.span.end,
            ),
            _ => {}
        }
    }

    let after_last_import = imports.iter().map(|i| i.statement_end).max().unwrap_or(0);
    Collected {
        declarations,
        declaration_spans: spans,
        imports,
        after_last_import,
    }
}

fn collect_import(
    text: &str,
    import: &oxc_ast::ast::ImportDeclaration<'_>,
    imports: &mut Vec<ImportInfo>,
) {
    let mut specifiers = Vec::new();
    let mut brace_open = None;
    let mut brace_close = None;
    if let Some(entries) = &import.specifiers {
        for entry in entries.iter() {
            match entry {
                ImportDeclarationSpecifier::ImportSpecifier(spec) => {
                    specifiers.push(spec.local.name.to_string())
                }
                ImportDeclarationSpecifier::ImportDefaultSpecifier(_) => {
                    specifiers.push("default".to_string())
                }
                ImportDeclarationSpecifier::ImportNamespaceSpecifier(_) => {
                    specifiers.push("*".to_string())
                }
            }
        }
        // the named-entry braces, if the statement has them
        let statement = &text[import.span.start as usize..import.span.end as usize];
        if let Some(open) = statement.find('{')
            && let Some(close) = statement.rfind('}')
        {
            brace_open = Some(import.span.start + open as u32 + 1);
            brace_close = Some(import.span.start + close as u32);
        }
    }
    imports.push(ImportInfo {
        source: import.source.value.as_str().unwrap_or_default().to_string(),
        type_only: import.import_kind.is_type(),
        specifiers,
        statement_end: import.span.end,
        brace_open,
        brace_close,
    });
}

fn exported_name(name: &ModuleExportName<'_>) -> String {
    match name {
        ModuleExportName::IdentifierName(ident) => ident.name.to_string(),
        ModuleExportName::IdentifierReference(ident) => ident.name.to_string(),
        ModuleExportName::StringLiteral(literal) => {
            literal.value.as_str().unwrap_or_default().to_string()
        }
    }
}

fn collect_declaration(declaration: &Declaration<'_>, push: &mut dyn FnMut(String)) {
    match declaration {
        Declaration::FunctionDeclaration(function) => {
            if let Some(ident) = &function.id {
                push(ident.name.to_string());
            }
        }
        Declaration::ClassDeclaration(class) => {
            if let Some(ident) = &class.id {
                push(ident.name.to_string());
            }
        }
        Declaration::VariableDeclaration(variables) => {
            for declarator in &variables.declarations {
                for ident in declarator.id.get_binding_identifiers() {
                    push(ident.name.to_string());
                }
            }
        }
        Declaration::TSTypeAliasDeclaration(alias) => push(alias.id.name.to_string()),
        Declaration::TSInterfaceDeclaration(interface) => push(interface.id.name.to_string()),
        Declaration::TSEnumDeclaration(enum_decl) => push(enum_decl.id.name.to_string()),
        _ => {}
    }
}
