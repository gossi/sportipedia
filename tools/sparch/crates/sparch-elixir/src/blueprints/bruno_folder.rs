use std::path::Path;

use sparch_model::ElementKind;

use crate::context::Context;
use crate::plan::{Blueprint, FilePlan};

const FOLDER_PATH: &str = "bruno/<Subdomain>/<Composite>/<Constituent>/folder.yml";

pub struct BrunoFolder;

impl BrunoFolder {
    pub fn folder_path(ctx: &Context) -> String {
        ctx.render_or_panic(FOLDER_PATH)
    }
}

impl Blueprint for BrunoFolder {
    fn name(&self) -> &'static str {
        "bruno_folder"
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command, ElementKind::Query]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(FOLDER_PATH, "folder defaults for requests")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        let path = BrunoFolder::folder_path(ctx);
        let mut plan = FilePlan::new(path.clone(), None, Vec::new());
        plan.scaffold = Some(folder_scaffold(ctx, &path));
        plan.format = false;
        plan.unit_created = false;
        vec![plan]
    }
}

fn folder_scaffold(ctx: &Context, path: &str) -> String {
    format!(
        "info:\n  name: {}\n  type: folder\n  seq: {}\n\nrequest:\n  auth: inherit\n",
        Context::pascal(&ctx.constituent),
        folder_seq(ctx, path)
    )
}

fn folder_seq(ctx: &Context, path: &str) -> usize {
    let folder = Path::new(path);
    let Some(own) = folder.parent().and_then(Path::parent) else {
        return 1;
    };
    let composite = ctx.repo_root.join(own);
    if !composite.is_dir() {
        return 1;
    }
    let Ok(entries) = std::fs::read_dir(&composite) else {
        return 1;
    };
    let present = ctx
        .repo_root
        .join(Path::new(path).parent().unwrap())
        .is_dir();
    let count = entries
        .filter_map(|entry| entry.ok())
        .filter(|entry| entry.path().is_dir())
        .count();
    if present { count.max(1) } else { count + 1 }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use sparch_model::Model;
    use std::path::PathBuf;

    fn model() -> Model {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        Model::load(&root.canonicalize().expect("fixture corpus"))
    }

    fn ctx_in(root: PathBuf) -> Context {
        let element = model()
            .resolve("create-widget", &[ElementKind::Command])
            .expect("fixture command");
        Context::build(
            &model(),
            &element,
            &ContextOptions {
                repo_root: root,
                ..Default::default()
            },
        )
        .expect("context builds")
    }

    #[test]
    fn the_folder_is_a_plain_yaml_artifact() {
        let ctx = ctx_in(std::env::temp_dir());
        let plan = BrunoFolder.plans(&ctx).remove(0);
        assert_eq!(plan.path, "bruno/Catalog/Equipment/Widget/folder.yml");
        assert!(!plan.format);
        assert!(!plan.unit_created);
        assert!(plan.module.is_none());
    }

    #[test]
    fn the_folder_names_the_constituent_and_starts_at_one() {
        let root = std::env::temp_dir().join("sparch-elixir-bruno-folder-new");
        let _ = std::fs::remove_dir_all(&root);
        let ctx = ctx_in(root.clone());
        let scaffold = BrunoFolder
            .plans(&ctx)
            .remove(0)
            .scaffold
            .expect("a folder renders");
        assert_eq!(
            scaffold,
            "info:\n  name: Widget\n  type: folder\n  seq: 1\n\nrequest:\n  auth: inherit\n"
        );
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn the_folder_counts_the_sibling_constituent_folders() {
        let root = std::env::temp_dir().join("sparch-elixir-bruno-folder-siblings");
        let _ = std::fs::remove_dir_all(&root);
        std::fs::create_dir_all(root.join("bruno/Catalog/Equipment/Apparatus")).unwrap();
        let ctx = ctx_in(root.clone());
        let path = BrunoFolder::folder_path(&ctx);
        assert_eq!(
            folder_seq(&ctx, &path),
            2,
            "Apparatus is present and Widget counts as this run writes it"
        );
        std::fs::create_dir_all(root.join("bruno/Catalog/Equipment/Widget")).unwrap();
        assert_eq!(folder_seq(&ctx, &path), 2, "the same answer once it exists");
        let _ = std::fs::remove_dir_all(&root);
    }
}
