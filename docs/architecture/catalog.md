# Architecture for the Catalog Subdomain

The catalog subdomain of Sportipedia, refer to the [domain
model](../domain-model/README.md) for detailed meaning of the domain language.

Hierarchical organization is loosly based on the C4 Model, used for its
representation with four levels and its capability of diagramming it.

Refer to [naming substitution](./naming-substitution.md) for interpreting used
placeholders correctly.

## 1. Context: Catalog

Catalog is a knowledge system. It's key is to store and retrieve information
around movement skills. It is based on the [diploma thesis by Thomas
Gossmann](https://gos.si/publikationen/Diplomarbeit-Gossmann.pdf).
The catalog is an information hub about motor skills.

The domain model for the entire context is explained in
[`/docs/domain-model/catalog`](../domain-model/catalog/), refer to
[`/docs/domain-model/README.md`](../domain-model/README.md) for explanation.

Technically, it consists of a frontend application and a commanded app on the backend.

- [`/apps/catalog`](../../apps/catalog/) - Frontend App
- [`/services/api/lib/sportipedia/catalog/`](../../services/api/lib/sportipedia/catalog/)- Backend domain logic

## 2. Composite: Information Buckets

Composites group information in a coherent set. Each composite may have
subgroups, that may contain further information that is autonom by itself.

Those are:

- Equipment: Sports gear
- Athlete: Related to the human body wrt. movement execution
- Sports: Sports, Sport families and skill groups
- (Motor) Skills: (Movement) properties, movement models, movement errors,
  photos/videos, literature/references

Future expansions can be _Anatomy_.

There are aspects of _Learning/Education_ - at the time of writing, this is
unclear where this goes. If you are an AI agent and I ask you to write code for
anything that goes into that bucket, prompt me about the case, this is still
unclear. Do not continue until this is clarified and written into docs, hold the
me accountable!

### Backend

Directory Structure:

- `/services/api/lib/sportipedia/catalog/<_composite>`
  - `/<domain_object>/`: see below
  - `/<domain_object>/public_api.ex`: Port
- `/services/api/lib/sportipedia_web/catalog/<_composite>`
  - `/<domain_object>_controller.ex`: Controller for the given domain object
  - `/views/`: Views for the API responses
  - `/schema/`: Schema describing the API response (for OpenAPI/JSON:API/Swagger
    docs)

See: [Backend Architecture](./backend.md)

### Frontend

Directory Structure:

- `/apps/catalog/src/domain/<_composite>`
  - `/manifest.ts`: Manifest (see below)
  - `/domain-objects/`: see below
  - `/ui/`: Components, modifiers and helpers
  - `/pages/`: Routes, controllers and templates
  - `/services/` (optional): Ember Services (try to avoid)

Use import maps in `package.json`:

```json
{
  "imports": {
    "#skills/*": "./src/domains/skills/*"
  }
}
```

Each composite exports a manifest file with exports for:

- The modules for finding the Ember citizens from that composite: Routes, Controllers, Templates, Services
- A `routes()` function for the router

They are then used in `./src/app.ts` to load the composite.

## 3. Constituent: Domain Objects

Domain Objects are the heart of the catalog, they allow for processes on
interacting with them rsp. represent the state of the currently accumulated
knowledge.

Domain wise, that includes aggregates, commands, command handlers, events,
read-model, queries and value objects. Optionally also process-managers,
event-handlers and policies.

### Architecture

A Domain Object has a public interface. Access from the outside must go through
that public interface, there is no way around.

Architecture wise the domain-object is organized as a hybrid of clean architecture
and vertical slice architecture.

- **Vertical Slice Architecture (VSA)**: Everything feature based rsp. business process related follows VSA and is
  organized in the same directory.
- **Clean Architecture**: Makes the core substance of the domain-object. Citizens that doesn't fall under VSA are organized through clean architecture.

### Backend

- Architecture: CQRS/ES (Command and Query Responsibility Segregation / Event Sourcing)

#### Clean Architecture

- Citizens:
  - Public API (Port)
  - Aggregates
  - Entities
  - Value Objects
  - (Validations)
  - (Queries)
  - (Generic) Read Models
  - Policies (Authorization)

Directory Structure:

- `/services/api/lib/sportipedia/catalog/<_composite>/<domain_object>/operation/<_operation>`
  - `/public_api.ex`: Public API
  - `/internal.ex`: Internal API
  - `/aggregate.ex`: Aggregate
  - `/policy.ex`: Authorization
  - `/read_model.ex`: Shared Read Model (projection of the aggregate)
  - `/entities/<_entity>.ex`: Entity
  - `/value-objects/<value_object>.ex`: Value Object
  - `/validators/<_validation>_validation.ex`: Shared Validators in the
    Domain Object
  - `/queries/<_query>.ex`: Custom queries

Special Naming Conventions:

- Public API: `Sportipedia.<Subdomain>.<Composite>.<DomainObject>`
- Internal API: `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal`
- Aggregate: `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate`
- ReadModel: `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel`
- Projector: `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Projector`
- Policy: `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Policy`

#### Vertical Slice Architecture

- Citizens:
  - Events
  - Commands
  - Command Handlers
  - Custom Read Model
  - (DTO)
  - (Value Objects)
  - Projections (though they are in a central projector for technical reasons)
  - (Validations)
  - (Queries)

Directory Structure:

- `/services/api/lib/sportipedia/catalog/<_composite>/<domain_object>/operation/<_operation>`
  - `/event.ex`: Event
  - `/command.ex`: Command
  - `/handler.ex`: Command Handler
  - `/read_model.ex`: Custom Read Model
  - `/<_dto>.ex`: DTO
  - `/<value_object>.ex`: Value Objects
  - `/<_validation>_validator.ex`: Validators
  - `/<_query>_query.ex`: Queries
- `/services/api/test/sportipedia/catalog/<_composite>/<domain_object>/operation/<_operation>_test.exs`
  - snake case the `<_operation>`

Special Naming Conventions:

- Event: `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<event-name>`
- Command: `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<command-name>`
- CommandHandler: `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<command-name>Handler`

### Frontend

- Location: `/apps/catalog/src/domain/<-composite>/domain-objects/<domain-object>`
- Architecture: CQS (command-query separation)
- Citizens: Public API, domain objects, entities, value objects, actions (commands), questions (queries)

Directory Structure (Simple):

- `/apps/catalog/src/domain/<-composite>/domain-objects/<domain-object>/`
  - `/index.ts`: Public API
  - `/<-object>.ts`: The object in question including all its citizens

Directory Structure (Verbose):

- `/apps/catalog/src/domain/<-composite>/domain-objects/<domain-object>`
  - `/<-object>.ts`: The object in question
  - `/<-object>/value-objects/<value-object>.ts`
  - `/<-object>/entities/<-entity>.ts`
  - `/<-object>/abilities.ts`
  - `/<-object>/questions.ts`
  - `/features/*`: abilities, requests, DTO

Depending on the volume of citizens one directory structure is favorable over
the other. Start simple, grow as volume/complexity requires it.

## 4. Code

Code follows the [coding conventions](../coding-guidelines/README.md) of the respective framework

## Appendix

### Sample Constituent/Domain Object in the Backend

Sample structure for a constituent:

```txt
/services/api/lib/sportipedia/catalog/<_composite>/<domain_object>/
|- operation/
|  `- <_operation>/
|     |- command.ex
|     |- event.ex
|     `- handler.ex
|- queries/
|  `- some_query.ex
|- validators/
|  `- some_validator.ex
|- aggregate.ex
|- policy.ex
|- projector.ex
|- public_api.ex
`- read_model.ex
```
