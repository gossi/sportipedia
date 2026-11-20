//! sparch — the generators' own tool: capability tree, embedded manual,
//! architectural answers (placement and naming), model validation, and
//! the generate face over the workspace engines. The MCP server reuses
//! this crate's query side; the `sparch` binary is its CLI face.

pub mod arch;
pub mod capabilities;
pub mod cli;
pub mod generate;
pub mod man;
pub mod manpage;
pub mod validate;
