//! `actions` — one request-option builder per command, shaped by the
//! read model's declared effect: create builds a record, update patches,
//! delete addresses. `none` is a decision (no materialization, still a
//! command → still an action, update-shaped). Missing declarations are
//! reported unresolved, never guessed.

use sparch_model::{Citizen, citizen::Command};

use super::{Output, Unit, declaration, import, jsdoc, union};
use crate::{layout::Layout, plan::FilePlan};

pub fn plan(citizen: &Citizen, layout: &Layout) -> Output {
    let mut plans = Output {
        plans: vec![],
        notes: vec![],
    };
    let mut units = vec![];
    let mut create_body = String::new();

    for command in &citizen.commands {
        let Some(effect) = &command.effect else {
            plans.notes.push(format!(
                "command {} publishes no event whose effect the read model {} declares — spgen.operation.<event> is missing",
                command.name, citizen.constituent
            ));
            continue;
        };
        let effect = effect.as_str();
        if effect == "none" {
            // no materialization; still an action — delete-style dispatch
            // would lie about the verb, so we render the create/update body
            // per the command's own data (update-shaped)
        }

        let code = render(citizen, command, effect);
        if matches!(effect, "create" | "update" | "none") {
            let mut data = data_type_unit(citizen, command, effect).with(import(
                &format!("./{}", citizen.constituent),
                true,
                &format!("{}Fields", citizen.type_name),
            ));
            if effect == "create" {
                data = data.with(import("@warp-drive/core/types/utils", true, "WithPartial"));
            }
            create_body.push_str(&data.text);
            create_body.push('\n');
            units.push(data);
        }
        create_body.push_str(&code.text);
        create_body.push('\n');
        units.push(code);
    }

    if units.is_empty() {
        return plans;
    }

    plans.plans.push(FilePlan {
        path: layout.actions(),
        host: false,
        create: Some(create(citizen, &create_body)),
        units,
    });
    plans
}

fn data_type_unit(citizen: &Citizen, command: &Command, effect: &str) -> Unit {
    declaration(
        &format!("{}Data", command.pascal),
        render_data(citizen, command, effect),
    )
}

fn render(citizen: &Citizen, command: &Command, effect: &str) -> Unit {
    let head = jsdoc(&[
        &format!("@group {}", citizen.type_name),
        "@category Actions",
    ]);
    let body = match effect {
        "create" => format!(
            concat!(
                "{head}export function {fn}(\n",
                "  data: {p}Data,\n",
                "  {{ store }}: {{ store: Store }}\n",
                "): CreateRequestOptions<{type}> {{\n",
                "  const {camel} = store.createRecord<{type}>('{constituent}', data);\n",
                "  const options = createRecord({camel}, {{\n",
                "    resourcePath: '{path}',\n",
                "    reload: true\n",
                "  }});\n\n",
                "  options.headers.append('Content-Type', 'application/vnd.api+json');\n",
                "  options.body = JSON.stringify({{\n",
                "    data: store.cache.peek(cacheKeyFor({camel}))\n",
                "  }});\n\n",
                "  return options;\n}}\n"
            ),
            head = head,
            fn = command.fn_name,
            p = command.pascal,
            type = citizen.type_name,
            camel = citizen.constituent,
            constituent = citizen.constituent,
            path = command.path,
        ),
        "update" | "none" => format!(
            concat!(
                "{head}export function {fn}(\n",
                "  record: ReactiveResource,\n",
                "  changes: {p}Data,\n",
                "  {{ store }}: {{ store: Store }}\n",
                "): UpdateRequestOptions {{\n",
                "  Object.assign(record, changes);\n\n",
                "  const requestOptions = updateRecord(record, {{\n",
                "    reload: true\n",
                "  }});\n\n",
                "  // @ts-expect-error warp-drive thinks, this must be PUT or PATCH (haiyaa, so wrong!)\n",
                "  requestOptions.method = 'POST';\n",
                "  requestOptions.url = buildBaseURL({{ resourcePath: '{path}' }});\n",
                "  requestOptions.headers.append('Content-Type', 'application/vnd.api+json');\n\n",
                "  const payload = serializePatch(store.cache, cacheKeyFor(record));\n\n",
                "  requestOptions.body = JSON.stringify(payload);\n\n",
                "  return requestOptions;\n}}\n"
            ),
            head = head,
            fn = command.fn_name,
            p = command.pascal,
            path = command.path,
        ),
        _ => format!(
            concat!(
                "{head}export function {fn}(\n",
                "  record: ReactiveResource,\n",
                "  {{ store }}: {{ store: Store }}\n",
                "): DeleteRequestOptions<ReactiveResource> {{\n",
                "  const requestOptions = deleteRecord(record);\n\n",
                "  // @ts-expect-error warp-drive thinks, this must be DELETE (haiyaa, so wrong!)\n",
                "  requestOptions.method = 'POST';\n",
                "  requestOptions.url = buildBaseURL({{ resourcePath: '{path}' }});\n",
                "  requestOptions.headers.append('Content-Type', 'application/vnd.api+json');\n\n",
                "  const payload = serializeResources(store.cache, cacheKeyFor(record));\n\n",
                "  requestOptions.body = JSON.stringify(payload);\n\n",
                "  return requestOptions;\n}}\n"
            ),
            head = head,
            fn = command.fn_name,
            path = command.path,
        ),
    };
    let unit = declaration(&command.fn_name, body);
    // the imports this body needs ride with it — placed only when the
    // body is, and each skipped when already present
    match effect {
        "create" => unit
            .with(import("@warp-drive/core", false, "cacheKeyFor"))
            .with(import(
                "@warp-drive/utilities/json-api.cjs",
                false,
                "createRecord",
            ))
            .with(import(
                "@warp-drive/core/types/request",
                true,
                "CreateRequestOptions",
            ))
            .with(import(
                &format!("./{}", citizen.constituent),
                true,
                &citizen.type_name,
            ))
            .with(import("#support/data", true, "Store")),
        "update" | "none" => unit
            .with(import("@warp-drive/core", false, "cacheKeyFor"))
            .with(import("@warp-drive/utilities", false, "buildBaseURL"))
            .with(import(
                "@warp-drive/utilities/json-api.cjs",
                false,
                "updateRecord",
            ))
            .with(import(
                "@warp-drive/utilities/json-api.cjs",
                false,
                "serializePatch",
            ))
            .with(import(
                "@warp-drive/core/reactive",
                true,
                "ReactiveResource",
            ))
            .with(import(
                "@warp-drive/core/types/request",
                true,
                "UpdateRequestOptions",
            ))
            .with(import("#support/data", true, "Store")),
        _ => unit
            .with(import("@warp-drive/core", false, "cacheKeyFor"))
            .with(import("@warp-drive/utilities", false, "buildBaseURL"))
            .with(import(
                "@warp-drive/utilities/json-api.cjs",
                false,
                "deleteRecord",
            ))
            .with(import(
                "@warp-drive/utilities/json-api.cjs",
                false,
                "serializeResources",
            ))
            .with(import(
                "@warp-drive/core/reactive",
                true,
                "ReactiveResource",
            ))
            .with(import(
                "@warp-drive/core/types/request",
                true,
                "DeleteRequestOptions",
            ))
            .with(import("#support/data", true, "Store")),
    }
}

/// The Data type is a *view of `XFields`* — pure derivation in the spirit
/// of WarpDrive's narrowing-types doc, never a second shape. Requiredness
/// comes from the command itself: create keeps its required keys via
/// `WithPartial` listing only the optional ones; update is `Partial`
/// (PATCH: omitted means unchanged). There is no `& { … }` tail: a command
/// input that is not a writable resource field is a model bug, and the
/// renderer ignores it rather than typing the bug into the API.
fn render_data(citizen: &Citizen, command: &Command, effect: &str) -> String {
    let fields = format!("{}Fields", citizen.type_name);
    let text = if effect == "create" {
        if command.partials.is_empty() {
            format!("type {}Data = {};", command.pascal, fields)
        } else {
            format!(
                "type {}Data = WithPartial<{}, {}>;",
                command.pascal,
                fields,
                union(&command.partials)
            )
        }
    } else {
        format!("type {}Data = Partial<{}>;", command.pascal, fields)
    };
    format!("\n{text}\n")
}

fn create(citizen: &Citizen, body: &str) -> String {
    let mut text = jsdoc(&[
        &format!("@module {} Actions", citizen.type_name),
        &format!("@mergeModuleWith {}", citizen.type_name),
    ]);
    text.push_str("import { cacheKeyFor } from '@warp-drive/core';\n");
    text.push_str("import { buildBaseURL } from '@warp-drive/utilities';\n");
    text.push_str("import {\n  createRecord,\n  deleteRecord,\n  serializePatch,\n  serializeResources,\n  updateRecord\n} from '@warp-drive/utilities/json-api.cjs';\n\n");
    text.push_str(&format!(
        "import type {{ {}, {}Fields }} from './{}';\n",
        citizen.type_name, citizen.type_name, citizen.constituent
    ));
    text.push_str("import type { ReactiveResource } from '@warp-drive/core/reactive';\n");
    text.push_str("import type {\n  CreateRequestOptions,\n  DeleteRequestOptions,\n  UpdateRequestOptions\n} from '@warp-drive/core/types/request';\n");
    text.push_str("import type { WithPartial } from '@warp-drive/core/types/utils';\n");
    text.push_str("import type { Store } from '#support/data';\n\n");
    text.push_str(body);
    text
}
