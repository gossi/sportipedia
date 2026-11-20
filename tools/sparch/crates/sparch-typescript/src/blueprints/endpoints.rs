//! `endpoints` — the MSW endpoint descriptors and mock handlers per
//! command and query. Paths come from the ported route convention:
//! `**/<namespace>/<composite>/<plural>[/<command>]`.

use sparch_model::{Case, Citizen, Name, citizen::QueryKind};

use super::{Output, declaration, import, out};
use crate::{layout::Layout, plan::FilePlan};

pub fn plan(citizen: &Citizen, layout: &Layout) -> Output {
    if citizen.commands.is_empty() && citizen.queries.is_empty() {
        return out(vec![]);
    }

    let namespace = &citizen.subdomain; // apps/catalog serves /catalog/…
    let plural = Name::parse(&citizen.constituent).plural_kebab();
    let collection = Name::parse(&citizen.constituent).render_plural(Case::Screaming);
    let fixtures_file = layout.fixtures();

    let mut response_body = String::new();
    let mut endpoint_body = String::new();
    let mut mock_body = String::new();
    let mut units = vec![];

    let response = declaration(
        &format!("make{}Response", citizen.type_name),
        make_response(citizen),
    );
    response_body.push_str(&response.text);
    units.push(response);

    for command in &citizen.commands {
        let pascal = Name::parse(&command.name).render(Case::Pascal);
        let endpoint_name = format!("make{pascal}Endpoint");
        let mock_name = format!("mock{pascal}");

        let endpoint = declaration(
            &endpoint_name,
            endpoint_fn(&endpoint_name, None, "POST", namespace, &command.path),
        );
        let mock = declaration(&mock_name, mock_create(citizen, &endpoint_name));
        endpoint_body.push_str(&endpoint.text);
        endpoint_body.push('\n');
        mock_body.push_str(&mock.text);
        mock_body.push('\n');
        units.push(endpoint);
        units.push(mock);
    }

    for query in &citizen.queries {
        let pascal = Name::parse(&query.name).render(Case::Pascal);
        let endpoint_name = format!("make{pascal}Endpoint");
        let mock_name = format!("mock{pascal}");

        match query.kind {
            QueryKind::Read => {
                let param = query.param.clone().unwrap_or_else(|| "id".to_string());
                let endpoint = declaration(
                    &endpoint_name,
                    endpoint_fn(&endpoint_name, Some(&param), "GET", namespace, &query.path),
                );
                let accessor = query
                    .params
                    .iter()
                    .find(|p| p.as_str() != "id")
                    .cloned()
                    .unwrap_or_else(|| "id".to_string());
                let mock = declaration(
                    &mock_name,
                    mock_read(citizen, &endpoint_name, &mock_name, &accessor),
                );
                endpoint_body.push_str(&endpoint.text);
                mock_body.push_str(&mock.text);
                units.push(endpoint);
                units.push(mock);
            }
            QueryKind::Collection => {
                let endpoint = declaration(
                    &endpoint_name,
                    endpoint_fn(&endpoint_name, None, "GET", namespace, &query.path),
                );
                // a collection mock defaults to the fixtures collection
                // when the citizen has examples — and gates on that file
                // while it is not there; without examples the mock simply
                // takes its data explicitly
                let has_fixtures = !citizen.fixtures.is_empty();
                let mut mock = declaration(
                    &mock_name,
                    mock_collection(
                        citizen,
                        &endpoint_name,
                        &mock_name,
                        &collection,
                        has_fixtures,
                    ),
                );
                if has_fixtures {
                    mock.gate = vec![fixtures_file.clone()];
                    mock = mock.with(import(&format!("../fixtures/{plural}"), false, &collection));
                }
                endpoint_body.push_str(&endpoint.text);
                endpoint_body.push('\n');
                mock_body.push_str(&mock.text);
                mock_body.push('\n');
                units.push(endpoint);
                units.push(mock);
            }
        }
    }

    out(vec![
        FilePlan {
            path: layout.endpoints(),
            host: false,
            create: Some(create(
                citizen,
                &plural,
                &collection,
                &response_body,
                &endpoint_body,
                &mock_body,
            )),
            units,
        },
        barrel_plan(citizen, layout, &plural),
    ])
}

/// Names this artifact contributes to the test-support barrel block.
pub fn barrel_names(citizen: &Citizen) -> Vec<String> {
    let mut names: Vec<String> = vec![format!("make{}Response", citizen.type_name)];
    for command in &citizen.commands {
        let pascal = Name::parse(&command.name).render(Case::Pascal);
        names.push(format!("make{pascal}Endpoint"));
        names.push(format!("mock{pascal}"));
    }
    for query in &citizen.queries {
        let pascal = Name::parse(&query.name).render(Case::Pascal);
        names.push(format!("make{pascal}Endpoint"));
        names.push(format!("mock{pascal}"));
    }
    names.sort();
    names
}

/// The test-support barrel keeps a re-export block for the endpoints file.
/// This artifact owns that block: with fixtures present the block gates on
/// the fixtures file (the collection mock defaults to it), otherwise the
/// endpoints file is ungated and the barrel is created here.
fn barrel_plan(citizen: &Citizen, layout: &Layout, plural: &str) -> FilePlan {
    let source = format!("./queries/{plural}");
    let names = barrel_names(citizen);
    let gate = if citizen.fixtures.is_empty() {
        vec![]
    } else {
        vec![layout.fixtures()]
    };
    super::barrel_plan(layout, &source, &names, gate)
}

fn endpoint_fn(name: &str, param: Option<&str>, method: &str, ns: &str, path: &str) -> String {
    let args = param.map(|p| format!("{p}: string")).unwrap_or_default();
    let suffix = param.map(|p| format!("/${{{p}}}")).unwrap_or_default();
    format!(
        "\nexport function {name}({args}): Endpoint {{\n  return {{ method: '{method}', path: `**/{ns}/{path}{suffix}` }};\n}}\n"
    )
}

fn make_response(citizen: &Citizen) -> String {
    format!(
        "\nexport function make{}Response({}: {}): ResponseResolver {{\n  return makeJsonResponder(toJsonApiDocument(toResource({})));\n}}\n",
        citizen.type_name, citizen.constituent, citizen.type_name, citizen.constituent
    )
}

fn mock_create(citizen: &Citizen, endpoint: &str) -> String {
    let name = format!(
        "mock{}",
        &endpoint["make".len()..endpoint.len() - "Endpoint".len()]
    );
    format!(
        concat!(
            "\nexport function {name}(): RequestHandler {{\n",
            "  return mock({endpoint}(), async ({{ request }}) => {{\n",
            "    const {c} = (await request.json()) as {type};\n\n",
            "    return HttpResponse.json(toJsonApiDocument(toResource({c})));\n  }});\n}}\n"
        ),
        name = name,
        endpoint = endpoint,
        c = citizen.constituent,
        type = citizen.type_name,
    )
}

fn mock_read(citizen: &Citizen, endpoint: &str, name: &str, accessor: &str) -> String {
    format!(
        concat!(
            "\nexport function {name}({c}: {type}): RequestHandler {{\n",
            "  return mock({endpoint}({c}.{accessor}), make{type}Response({c}));\n}}\n"
        ),
        name = name,
        endpoint = endpoint,
        c = citizen.constituent,
        type = citizen.type_name,
        accessor = accessor,
    )
}

fn mock_collection(
    citizen: &Citizen,
    endpoint: &str,
    name: &str,
    collection: &str,
    has_fixtures: bool,
) -> String {
    let plural_arg =
        Name::parse(&Name::parse(&citizen.constituent).plural_kebab()).render(Case::Camel);
    let default = if has_fixtures {
        format!(" = {collection}")
    } else {
        String::new()
    };
    format!(
        concat!(
            "\nexport function {name}({plural_arg}: {type}[]{default}): RequestHandler {{\n",
            "  const data = {plural_arg}.map(({c}) => toResource({c}));\n\n",
            "  return mock({endpoint}(), makeJsonResponder(toJsonApiDocument(data)));\n}}\n"
        ),
        name = name,
        plural_arg = plural_arg,
        default = default,
        endpoint = endpoint,
        c = citizen.constituent,
        type = citizen.type_name,
    )
}

fn create(
    citizen: &Citizen,
    plural: &str,
    collection: &str,
    response: &str,
    endpoints: &str,
    mocks: &str,
) -> String {
    let mut text = String::from(
        "import { HttpResponse, type RequestHandler, type ResponseResolver } from 'msw';\n\n",
    );
    text.push_str("import { toJsonApiDocument } from '#test-support/data/jsonapi.ts';\n");
    text.push_str("import { toResource } from '#test-support/data/resources.ts';\n");
    text.push_str("import { type Endpoint, makeJsonResponder, mock } from '#test-support/msw';\n");
    if !citizen.fixtures.is_empty()
        && citizen
            .queries
            .iter()
            .any(|q| q.kind == QueryKind::Collection)
    {
        text.push_str(&format!(
            "\nimport {{ {collection} }} from '../fixtures/{plural}';\n"
        ));
    }
    text.push_str(&format!(
        "\nimport type {{ {} }} from '{}';\n",
        citizen.type_name,
        Layout::barrel_alias(&citizen.composite)
    ));
    text.push_str("\n// Utils\n");
    text.push_str(response);
    text.push_str("\n// Endpoints\n");
    text.push_str(endpoints);
    text.push_str("\n// Mocks\n");
    text.push_str(mocks);
    text
}
