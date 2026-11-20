//! App layout — where the FE citizen lives. Vertical slices under the
//! composite directory, test support beside it, barrels and hosts as the
//! registration points. `apps/admin` can be added the day it earns it.

use std::path::PathBuf;

use sparch_model::Citizen;

pub struct Layout {
    pub app: String,
    pub composite: String,
    pub constituent: String,
    pub plural: String,
}

impl Layout {
    pub fn new(citizen: &Citizen) -> Self {
        Layout {
            app: citizen.subdomain.clone(),
            composite: citizen.composite.clone(),
            constituent: citizen.constituent.clone(),
            plural: sparch_model::Name::parse(&citizen.constituent).plural_kebab(),
        }
    }

    pub fn domain_object(&self) -> PathBuf {
        self.src()
            .join("domain-objects")
            .join(&self.constituent)
            .join(format!("{}.ts", self.constituent))
    }

    pub fn abilities(&self) -> PathBuf {
        self.src()
            .join("domain-objects")
            .join(&self.constituent)
            .join("abilities.ts")
    }

    pub fn actions(&self) -> PathBuf {
        self.src()
            .join("domain-objects")
            .join(&self.constituent)
            .join("actions.ts")
    }

    pub fn queries(&self) -> PathBuf {
        self.src()
            .join("domain-objects")
            .join(&self.constituent)
            .join("queries.ts")
    }

    pub fn schema(&self) -> PathBuf {
        self.src()
            .join("schemas")
            .join(format!("{}.ts", self.constituent))
    }

    pub fn barrel(&self) -> PathBuf {
        self.src().join("index.ts")
    }

    pub fn config(&self) -> PathBuf {
        PathBuf::from("apps")
            .join(&self.app)
            .join("src")
            .join("config.ts")
    }

    pub fn fixtures(&self) -> PathBuf {
        self.tests()
            .join("support")
            .join("fixtures")
            .join(format!("{}.ts", self.plural))
    }

    pub fn endpoints(&self) -> PathBuf {
        self.tests()
            .join("support")
            .join("queries")
            .join(format!("{}.ts", self.plural))
    }

    pub fn test_barrel(&self) -> PathBuf {
        self.tests().join("support").join("index.ts")
    }

    pub fn storybook(&self) -> PathBuf {
        self.tests().join("support").join("storybook.ts")
    }

    pub fn ability_test(&self) -> PathBuf {
        self.tests()
            .join("domain-objects")
            .join(&self.constituent)
            .join("abilities.test.ts")
    }

    /// The test-support barrel alias of another composite (fixture refs).
    pub fn test_support_alias(composite: &str) -> String {
        format!("#{composite}-test-support")
    }

    pub fn barrel_alias(composite: &str) -> String {
        format!("#{composite}")
    }

    fn src(&self) -> PathBuf {
        PathBuf::from("apps")
            .join(&self.app)
            .join("src")
            .join(&self.composite)
    }

    fn tests(&self) -> PathBuf {
        PathBuf::from("apps")
            .join(&self.app)
            .join("tests")
            .join(&self.composite)
    }
}
