# Naming Substitution

Architecture documentation or skills contain templates for code or file-path
locations and make use of placeholders. These placeholders are later substituted
with the actual name they represent. Given different situations, these
placeholders have different casing (upper case, lower case, camel case, etc).
Second, these placeholders are re-occurring names coming from the domain model,
they are both explained here. Placeholders are enclosed as with angle-brackets,
eg. `<i-am-a-placeholder>`.

## Casing

Placeholders use a formal syntax to express the case that is
needed in a template for that given situation.

Placeholders can be one word or two words. The cases are represented
unambigously for one word. There is a two word alternative that can be used as
well, which makes reading and writing the templates much more natural.

| Case | One Word | Two Words | Sample |
| -- | -- | -- | --- |
| kebap-case | `<-subdomain>` | `<domain-object>` | `catalog-apparatus` |
| snake_case | `<_subdomain>` | `<domain_object>` | `catalog_apparatus` |
| PascalCase | `<Subdomain>` | `<DomainObject>` | `CatalogApparatus` |
| camelCase | `<subdomain>` | `<domainObject>` | `catalogApparatus` |
| spaces | - | `<desrcibe the situation>` | Fill this out by context |

## Variables

A variable maps to a target within a given source.

The source can be:

- `ESDM` and maps to a
  [`kind`](https://www.esdm.io/reference/core-schema/overview/#kinds). The value
  is then found in the `name` attribute
- `Arch` - in the related architecture documentation.

Here is a mapping between the variable names and their target. Some map to
architecture concepts, other to [ESDM
`kind`'s](https://www.esdm.io/reference/core-schema/overview/#kinds). In ESDM's
case, the value is then found in the `name` attribute.

| Variable | Source | Target | Comment |
| --- | --- | --- | --- |
| `<Command>` | ESDM | `command` | - |
| `<Event>` | ESDM | `event` | - |
| `<Subdomain>` | ESDM | `subdomain` | - |
| `<Operation>` | ESDM | `command` and `query` | - |
| `<Composite>` | Arch | `composite` | - |
| `<Constituent>` | Arch | `constituen` | - |
| `<DomainObject>` | Arch | `constituent` | Relates to [ESDM: `aggregate`](https://www.esdm.io/reference/core-schema/aggregate/), [ESDM: `read-model`](https://www.esdm.io/reference/core-schema/read-model/) |

## Substitution Samples

These samples show how placeholders in templates resolve to actual code.
All samples use these domain model values:

| Variable | Value |
|---|---|
| `<Subdomain>` / `<_subdomain>` / `<-subdomain>` / `<subdomain>` | `catalog` |
| `<Composite>` | `equipment` |
| `<DomainObject>` / `<domain-object>` / `<domain_object>` | `apparatus` |
| `<Command>` | `catalog-apparatus` |
| `<Event>` | `apparatus-cataloged` |

### Module Names

| Template | Resolved |
|---|---|
| `Sportipedia.<Subdomain>.<Composite>.<DomainObject>` | `Sportipedia.Catalog.Equipment.Apparatus` |
| `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate` | `Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate` |
| `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>` | `Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus` |
| `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>` | `Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged` |
| `SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>Controller` | `SportipediaWeb.Catalog.Equipment.ApparatusController` |
| `SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>View` | `SportipediaWeb.Catalog.Equipment.ApparatusView` |
| `SportipediaWeb.<Subdomain>.<Composite>.Schemas.<DomainObject>Response` | `SportipediaWeb.Catalog.Equipment.Schemas.ApparatusResponse` |

### File Paths

| Template | Resolved |
|---|---|
| `/services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/public_api.ex` | `/services/api/lib/sportipedia/catalog/equipment/apparatus/public_api.ex` |
| `/services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<-command>/handler.ex` | `/services/api/lib/sportipedia/catalog/equipment/apparatus/operation/catalog-apparatus/handler.ex` |
| `/services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>_controller.ex` | `/services/api/lib/sportipedia_web/catalog/equipment/apparatus_controller.ex` |
| `/services/api/lib/sportipedia_web/<_subdomain>/<composite>/schemas/<domain_object>_response.ex` | `/services/api/lib/sportipedia_web/catalog/equipment/schemas/apparatus_response.ex` |
| `/services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_command>_test.exs` | `/services/api/test/sportipedia/catalog/equipment/apparatus/operation/catalog_apparatus_test.exs` |
| `/services/api/test/sportipedia_web/<_subdomain>/<composite>/<_command>_request_test.exs` | `/services/api/test/sportipedia_web/catalog/equipment/catalog_apparatus_request_test.exs` |

### Function Names

| Template | Resolved |
|---|---|
| `def <_command>(conn, params)` | `def catalog_apparatus(conn, params)` |
| `def authorize(:<_command>, user, params)` | `def authorize(:catalog_apparatus, user, params)` |
| `<PublicAPI>.<_command>(params)` | `Apparatus.catalog_apparatus(params)` |
| `operation :<_command>` | `operation :catalog_apparatus` |

### Routes

| Template | Resolved |
|---|---|
| `post "/<-command>", <DomainObject>Controller, :<_command>` | `post "/catalog-apparatus", ApparatusController, :catalog_apparatus` |
| `get "/:<id>", <DomainObject>Controller, :read_<domain_object>` | `get "/:id", ApparatusController, :read_apparatus` |
| `scope "/<-subdomain>", SportipediaWeb.<Subdomain>` | `scope "/catalog", SportipediaWeb.Catalog` |
| `scope "/<composite>", <Composite>` | `scope "/equipment", Equipment` |
| `scope "/<domain-object>s"` | `scope "/apparatuses"` |

### JSON:API

| Template | Resolved |
|---|---|
| `type: "<domain-object>s"` | `type: "apparatuses"` |
| `path: "<-subdomain>/<composite>/<domain-object>s"` | `path: "catalog/equipment/apparatuses"` |
| `jsonapi_body("<domain-object>s", %{title: "Vault"})` | `jsonapi_body("apparatuses", %{title: "Vault"})` |

### OpenAPI / Schema

| Template | Resolved |
|---|---|
| `title: "<composite>.<DomainObject>"` | `title: "equipment.Apparatus"` |
| `title: "<composite>.<DomainObject>s"` | `title: "equipment.Apparatuses"` |
| `tags ["<composite>"]` | `tags ["equipment"]` |

### Test Module Names

| Template | Resolved |
|---|---|
| `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<_Command>Test` | `Sportipedia.Catalog.Equipment.Apparatus.Operation.CatalogApparatusTest` |
| `SportipediaWeb.<Subdomain>.<Composite>.<_Command>RequestTest` | `SportipediaWeb.Catalog.Equipment.CatalogApparatusRequestTest` |
