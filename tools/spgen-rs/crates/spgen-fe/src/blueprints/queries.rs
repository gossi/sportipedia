//! `queries` — one function per ESDM query against the read model:
//! `list-positions` → `listPositions`, `read-position` → `readPosition`.
//! Names from the model verbatim; pluralization only inside URL paths.

use spgen_model::{Citizen, citizen::QueryKind};

use super::{Output, Unit, declaration, import, jsdoc, out};
use crate::{layout::Layout, plan::FilePlan};

pub fn plan(citizen: &Citizen, layout: &Layout) -> Output {
    if citizen.queries.is_empty() {
        return out(vec![]);
    }

    let mut units = vec![];
    let mut body = String::new();

    for query in &citizen.queries {
        let mut unit = render(citizen, query);
        // the imports the query body needs ride with it
        unit = unit
            .with(import(
                &format!("./{}", citizen.constituent),
                true,
                &citizen.type_name,
            ))
            .with(import(
                "@warp-drive/core/reactive",
                true,
                "ReactiveDataDocument",
            ));
        unit = match query.kind {
            QueryKind::Collection => unit
                .with(import("@warp-drive/utilities/json-api", false, "query"))
                .with(import(
                    "@warp-drive/core/types/params",
                    true,
                    "QueryParamsSource",
                ))
                .with(import(
                    "@warp-drive/core/types/request",
                    true,
                    "QueryRequestOptions",
                )),
            QueryKind::Read => unit
                .with(import(
                    "@warp-drive/utilities/json-api",
                    false,
                    "findRecord",
                ))
                .with(import("@warp-drive/core/types", true, "FindRecordOptions"))
                .with(import(
                    "@warp-drive/core/types/request",
                    true,
                    "FindRecordRequestOptions",
                )),
        };
        body.push_str(&unit.text);
        body.push('\n');
        units.push(unit);
    }

    out(vec![FilePlan {
        path: layout.queries(),
        host: false,
        create: Some(create(citizen, &body)),
        units,
    }])
}

fn render(citizen: &Citizen, query: &spgen_model::citizen::Query) -> Unit {
    let head = jsdoc(&[
        &format!("@group {}", citizen.type_name),
        "@category Queries",
    ]);
    let text = match query.kind {
        QueryKind::Collection => format!(
            concat!(
                "{head}export function {fn}(\n",
                "  params: QueryParamsSource = {{}}\n",
                "): QueryRequestOptions<ReactiveDataDocument<{type}[]>> {{\n",
                "  return query<{type}>('{constituent}', params, {{ resourcePath: '{path}' }});\n}}\n"
            ),
            head = head,
            fn = query.fn_name,
            type = citizen.type_name,
            constituent = citizen.constituent,
            path = query.path,
        ),
        QueryKind::Read => format!(
            concat!(
                "{head}export function {fn}(\n",
                "  {param}: string,\n",
                "  params: FindRecordOptions = {{}}\n",
                "): FindRecordRequestOptions<ReactiveDataDocument<{type}>, {type}> {{\n",
                "  return findRecord<{type}>('{constituent}', {param}, {{\n",
                "    resourcePath: '{path}',\n",
                "    ...params\n",
                "  }});\n}}\n"
            ),
            head = head,
            fn = query.fn_name,
            param = query.param.clone().unwrap_or_else(|| "id".to_string()),
            type = citizen.type_name,
            constituent = citizen.constituent,
            path = query.path,
        ),
    };
    declaration(&query.fn_name, text)
}

fn create(citizen: &Citizen, body: &str) -> String {
    let mut text = jsdoc(&[
        &format!("@module {} Queries", citizen.type_name),
        &format!("@mergeModuleWith {}", citizen.type_name),
    ]);
    text.push_str("import { findRecord, query } from '@warp-drive/utilities/json-api';\n\n");
    text.push_str(&format!(
        "import type {{ {} }} from './{}';\n",
        citizen.type_name, citizen.constituent
    ));
    text.push_str("import type { ReactiveDataDocument } from '@warp-drive/core/reactive';\n");
    text.push_str("import type { FindRecordOptions } from '@warp-drive/core/types';\n");
    text.push_str("import type { QueryParamsSource } from '@warp-drive/core/types/params';\n");
    text.push_str("import type { FindRecordRequestOptions, QueryRequestOptions } from '@warp-drive/core/types/request';\n");
    text.push_str(body);
    text
}
