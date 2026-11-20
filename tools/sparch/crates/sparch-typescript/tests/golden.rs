//! Golden acceptance, ported in spirit from the BE test culture
//! (pickup, order independence, black box, fixture-driven):
//!
//! * a fresh tree, built in a "wrong" order — the position citizen is
//!   generated before the equipment citizens it references; its gated
//!   files defer, the subjects arrive, and the next run back-fills
//! * after completion, a re-run writes nothing (byte-stable)
//! * `--dry-run` on the finished tree is a clean no-op
//! * every generated file parses without a single diagnostic
//!
//! Inputs are the shared fixture corpus, never the live `docs/domain-model`.

use std::{
    collections::BTreeMap,
    fs,
    path::{Path, PathBuf},
    process::Command,
};

use oxc_allocator::Allocator;
use oxc_parser::Parser;
use oxc_span::SourceType;

fn corpus() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../fixtures/domain-model")
        .canonicalize()
        .expect("fixture corpus")
}

fn sandbox() -> PathBuf {
    static SEQ: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
    let seq = SEQ.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    let unique = format!(
        "{}-{seq}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    );
    let dir = std::env::temp_dir().join(format!("sparch-golden-{unique}"));
    fs::create_dir_all(dir.join("docs")).unwrap();
    fs::create_dir_all(dir.join("apps")).unwrap();

    // the model: the fixture corpus, presented at the repo location
    fs::create_dir_all(dir.join("docs/domain-model")).unwrap();
    copy_dir(&corpus(), &dir.join("docs/domain-model"));

    // registration hosts the generator must not invent
    fs::create_dir_all(dir.join("apps/catalog/src")).unwrap();
    fs::write(
        dir.join("apps/catalog/src/config.ts"),
        "import type { ApplicationInstance } from '@ember/application/instance';\n\
         import type { Store } from '#support/data';\n\n\
         function configureApi(app: ApplicationInstance) {\n\
         \x20 const store = app.lookup('service:store') as Store;\n\n\
         \x20 return store;\n\
         }\n\n\
         export function configure(app: ApplicationInstance) {\n\
         \x20 configureApi(app);\n\
         }\n",
    )
    .unwrap();

    // the roles the ability tests address
    let user = dir.join("apps/catalog/tests/user/support/fixtures");
    fs::create_dir_all(&user).unwrap();
    fs::write(
        user.join("index.ts"),
        "export const ADMIN = 'admin' as const;\n\
         export const GUEST = 'guest' as const;\n\
         export const USER = 'user' as const;\n",
    )
    .unwrap();

    dir
}

fn copy_dir(from: &Path, to: &Path) {
    for entry in fs::read_dir(from).unwrap() {
        let entry = entry.unwrap();
        let target = to.join(entry.file_name());
        if entry.file_type().unwrap().is_dir() {
            fs::create_dir_all(&target).unwrap();
            copy_dir(&entry.path(), &target);
        } else {
            fs::copy(entry.path(), target).unwrap();
        }
    }
}

fn sparch(root: &Path, args: &[&str]) -> (i32, String) {
    let binary = env!("CARGO_BIN_EXE_sparch-typescript");
    let output = Command::new(binary)
        .args(args)
        .args(["--repo-root", root.to_str().unwrap()])
        .output()
        .expect("run sparch");
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();
    (
        output.status.code().unwrap_or(-1),
        format!("{stdout}{stderr}"),
    )
}

fn tree(root: &Path) -> BTreeMap<PathBuf, String> {
    let mut files = BTreeMap::new();
    let base = root.join("apps/catalog");
    collect(&base, &mut files);
    files
}

fn collect(dir: &Path, files: &mut BTreeMap<PathBuf, String>) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for entry in entries.filter_map(Result::ok) {
        let path = entry.path();
        if path.is_dir() {
            collect(&path, files);
        } else if path.extension().is_some_and(|e| e == "ts") {
            files.insert(
                path.strip_prefix(dir).unwrap().to_path_buf(),
                fs::read_to_string(&path).unwrap(),
            );
        }
    }
}

fn assert_all_parse(root: &Path) {
    for (rel, text) in tree(root) {
        let allocator = Allocator::default();
        let source_type = SourceType::from_path(&rel).unwrap_or_else(|_| SourceType::ts());
        let ret = Parser::new(&allocator, &text, source_type).parse();
        assert!(
            !ret.fatal_error && ret.diagnostics.is_empty(),
            "generated file {} does not parse:\n{text}",
            rel.display()
        );
    }
}

#[test]
fn fresh_tree_completes_backfills_and_is_stable() {
    let root = sandbox();

    // 1. the dependent citizen first: the equipment subjects are missing,
    //    everything referencing them defers — never a broken import
    let (code, out) = sparch(&root, &["feature", "position"]);
    assert_eq!(code, 0, "deferring run must not fail: {out}");
    assert!(out.contains("deferred"), "expected deferrals: {out}");
    assert!(
        !out.contains("Created") || out.contains("position.ts"),
        "the ungated domain files arrive: {out}"
    );

    // 2. the referenced citizens
    for citizen in ["instrument", "apparatus"] {
        let (code, out) = sparch(&root, &["feature", citizen]);
        assert_eq!(code, 0, "{citizen}: {out}");
    }

    // 3. back-fill
    let (code, out) = sparch(&root, &["feature", "position"]);
    assert_eq!(code, 0, "back-fill: {out}");
    assert!(
        out.contains("Created"),
        "fixtures arrive on back-fill: {out}"
    );
    assert!(
        !out.contains("deferred"),
        "nothing may remain deferred: {out}"
    );

    // finders are model projections: parameters and predicates name real
    // properties only — never a lowercased kind like `byid`
    let fixtures =
        fs::read_to_string(root.join("apps/catalog/tests/athlete/support/fixtures/positions.ts"))
            .expect("positions fixtures");
    assert!(
        !fixtures.contains("byid") && !fixtures.contains("byslug"),
        "finder parameters must come from model properties:\n{fixtures}"
    );
    assert!(
        fixtures.contains("id: ID,") && fixtures.contains("slug: Slug,"),
        "finder parameters carry the property types:\n{fixtures}"
    );
    assert!(
        !fixtures.contains("findPositionByRawSlug"),
        "finders exist only for declared lookup params, not name matches:\n{fixtures}"
    );
    assert!(
        fixtures.contains("import type { ID, Slug } from '#/support/domain-objects/fields';"),
        "finder parameter types are imported:\n{fixtures}"
    );

    // storybook: defaults read the parameter (not the primary const), the
    // argTypes API is split into fields / with-preset, meta normalizes
    // the decorators union and delegates to the wrapper
    let storybook =
        fs::read_to_string(root.join("apps/catalog/tests/athlete/support/storybook.ts"))
            .expect("positions storybook");
    assert!(
        storybook.contains("title: position.title,")
            && !storybook.contains("UNICYCLE_RIDING.title"),
        "getPositionDefaultArgs must read its parameter:\n{storybook}"
    );
    assert!(
        storybook.contains("export function makePositionArgTypes(options")
            && storybook.contains("export function makePositionArgTypesWithPreset("),
        "argTypes split into fields and with-preset wrapper:\n{storybook}"
    );
    assert!(
        storybook.contains("...makePositionArgTypes(options)"),
        "the wrapper delegates to the field argTypes:\n{storybook}"
    );
    assert!(
        storybook.contains("Array.isArray(meta.decorators)")
            && storybook.contains("...makePositionArgTypesWithPreset(collection, options),"),
        "meta normalizes decorators and delegates argTypes:\n{storybook}"
    );

    // ability tests: valid chai matchers (a template that renders
    // `.totoBeTruthy()` parses fine — only content catches it)
    let abilities_test = fs::read_to_string(
        root.join("apps/catalog/tests/athlete/domain-objects/position/abilities.test.ts"),
    )
    .expect("abilities test");
    assert!(
        abilities_test.contains(".toBeTruthy();") && !abilities_test.contains("totoBe"),
        "chai matchers must be well-formed:\n{abilities_test}"
    );

    // 4. --force rewrites a stale generated declaration in place: tamper
    //    with one, watch it return — and nothing else moves
    let position_file = root.join("apps/catalog/src/athlete/domain-objects/position/position.ts");
    let pristine = fs::read_to_string(&position_file).expect("position.ts");
    let mut tampered = pristine.replace("readonly title: string;", "readonly title: number;");
    tampered = tampered.replace("interface Position extends", "interface Position  extends");
    fs::write(&position_file, &tampered).unwrap();

    let (code, out) = sparch(&root, &["feature", "position", "--force"]);
    assert_eq!(code, 0, "force run: {out}");
    assert!(out.contains("(rewritten)"), "force reports rewrites: {out}");
    let restored = fs::read_to_string(&position_file).expect("position.ts after force");
    assert!(
        restored.contains("readonly title: string;"),
        "force restored the tampered line:\n{restored}"
    );

    // --dry-run without --force flags nothing new afterwards
    let (code, out) = sparch(&root, &["feature", "position", "--dry-run"]);
    assert_eq!(code, 0, "{out}");
    assert!(
        !out.contains("would rewrite") && !out.contains("Updated"),
        "restored tree is clean: {out}"
    );

    // 5. byte-stable: a re-run writes nothing
    let before = tree(&root);
    let (_code, _out) = sparch(&root, &["feature", "position"]);
    assert_eq!(before, tree(&root), "re-run must not touch any file");

    // 5. pickup: --dry-run on the generated citizen is a no-op
    let (code, out) = sparch(&root, &["feature", "position", "--dry-run"]);
    assert_eq!(code, 0, "--dry-run: {out}");
    assert!(
        !out.contains("Updated")
            && !out.contains("Created")
            && !out.contains("Blocked")
            && !out.contains("deferred"),
        "--dry-run must be a no-op: {out}"
    );

    // 5a. the barrel was trimmed by hand (like the athlete file was):
    //     the configure function and its imports gone, the anchor with
    //     them. A run must re-materialize the reference structure —
    //     anchor-missing is a pending deferral the closure pass resolves
    //     in the same run, never a Failed
    let barrel = root.join("apps/catalog/src/athlete/index.ts");
    fs::write(
        &barrel,
        "// Modules\n\n// Routes\n\n// Data\n\n/**\n * @category Public API\n */\nexport type { Position } from './domain-objects/position/position.ts';\n",
    )
    .expect("strip barrel");

    let (code, out) = sparch(&root, &["feature", "position"]);
    assert_eq!(code, 0, "trimmed barrel must not fail the run: {out}");
    assert!(!out.contains("Failed"), "{out}");
    let restored = fs::read_to_string(&barrel).expect("barrel");
    assert!(
        !restored.contains(";//"),
        "imports must land on clean lines:\n{restored}"
    );
    assert!(
        restored.contains("configureAthleteSchema")
            && restored.contains("registerResources([positionSchema])")
            && restored.contains("positionSchema")
            && restored.contains("SchemaService"),
        "barrel not restored to the reference shape:\n{restored}"
    );
    assert!(
        restored.contains("export type { Position }"),
        "the surviving human line stays:\n{restored}"
    );

    // 5b. and the restored barrel is immediately pickup-clean
    let (code, out) = sparch(&root, &["feature", "position", "--dry-run"]);
    assert_eq!(code, 0, "{out}");
    assert!(
        !out.contains("Updated")
            && !out.contains("Created")
            && !out.contains("deferred")
            && !out.contains("Failed"),
        "restored barrel must be a no-op: {out}"
    );

    // 6. everything we wrote is real TypeScript
    assert_all_parse(&root);

    fs::remove_dir_all(&root).ok();
}

/// The bug this pins: the test-support barrel had a single owner
/// (fixtures), so a citizen without examples never got one — and its
/// contributors deferred their exports forever. The barrel obeys the BE
/// registration rule: every contributor owns its block; the first whose
/// file materializes creates the barrel; nothing dangles meanwhile.
#[test]
fn citizen_without_examples_still_gets_its_barrel() {
    let root = sandbox();
    let (code, out) = sparch(&root, &["feature", "exercise"]);
    assert_eq!(code, 0, "{out}");

    // the barrel exists, created by the endpoints block alone — no
    // fixtures or storybook block may dangle for a citizen without examples
    let barrel = root.join("apps/catalog/tests/exercises/support/index.ts");
    let text = fs::read_to_string(&barrel)
        .expect("endpoints must create the barrel when fixtures will not");
    assert!(text.contains("from './queries/exercises'"), "{text}");
    assert!(
        !text.contains("./fixtures/exercises"),
        "no fixtures block: {text}"
    );
    assert!(!text.contains("./storybook"), "no storybook block: {text}");

    // the collection mock takes its data explicitly — no default to gate on
    let endpoints =
        fs::read_to_string(root.join("apps/catalog/tests/exercises/support/queries/exercises.ts"))
            .expect("endpoints file");
    assert!(
        endpoints.contains("mockListExercises(exercises: Exercise[]): RequestHandler"),
        "{endpoints}"
    );
    assert!(
        !endpoints.contains("EXERCISES"),
        "no fixtures const without examples:\n{endpoints}"
    );

    // a second pass is a clean no-op — no permanent block-pending state
    let (code, out) = sparch(&root, &["feature", "exercise", "--dry-run"]);
    assert_eq!(code, 0, "{out}");
    assert!(
        !out.contains("Updated") && !out.contains("Created") && !out.contains("deferred"),
        "{out}"
    );

    assert_all_parse(&root);
    fs::remove_dir_all(&root).ok();
}
