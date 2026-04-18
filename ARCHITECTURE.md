# Architecture

The project Sportipedia follows C4 Model as well as Domain-Driven Design (DDD):

## 1. System: Sportipedia

The system is language wise a bounded context in the domain of sport science.
All domain terms should follow their definitions from established literature and are not meant to change within thi system.

## 2. Container: Catalog and Admin Apps

The container holds a huge part of the system or technically relevant parts (eg. admin)

### Backend

They are a commanded app running on the API microservice

Location: `/services/api/lib/sportipedia/<app>`

### Frontend

They are represented by an ember app

Location: `/apps/<app>`

## 3. Component: Core Subdomains as in DDD

For the catalog these are: Equipment, Exercise, Athlete, Skills and Sports

### Backend

- Location: `/services/api/lib/sportipedia/<app>/<subdomain>/<feature>`
- Architecture: Hybrid of Clean Architecture + Vertical Slice Architecture, CQRS/ES (Command and Query Responsibility Segregation / Event Sourcing)

#### Clean Architecture in `./<app>/<subdomain>`, contains

- Aggregate
- Entities
- Value Objects
- Validations (optional)
- Queries (optional)

> [!NOTE] Example
>
> ```txt
> ./catalog/skills
> - aggregate.ex
> ```

#### Vertical Slice Architecture in `./<app>/<subdomain>/<feature>`

Contains:

- DTO
- Value Objects
- Events
- Commands
- Command Handlers
- Projections
- Validations (optional)
- Queries (optional)

> [!NOTE] Example
>
> ```txt
> ./catalog/skills/catalog-skill
> - event.ex
> - command.ex
> - command-handler.ex
> ```

### Frontend

- Location: `/apps/<app>/src/domain/<subdomain>`
- Architecture: Clean Architecture, CQS (command-query separation)

Directory Structure:

- `domain-objects/`: For domain objects, entities, value objects, actions (commands), questions (queries)
  - Simple: `./<object>.ts`
  - Verbose:
    - `./<object>.ts`
    - `./<object>/value-objects/<value-object>.ts`
    - `./<object>/entities/<entity>.ts`
    - `./<object>/abilities.ts`
    - `./<object>/questions.ts`
  - Hybrid: As complexity grows, parts can be extracted, questions/abilities stay with the value objects, etc.
- `ui/`: Components, modifiers and helpers
- `pages/`: Routes, controllers and templates
- `services/` (optional): Ember Services (try to avoid)

Use import maps:

```json
{
  "imports": {
    "#skills/*": "./src/domains/skills/*"
  }
}
```

Each subdomain exports a manifest file with exports for:

- The modules for finding the Ember citizens from that subdomain: Routes, Controllers, Templates, Services
- A `routes()` function

They are then used in `./src/app.ts` to load the subdomain.

## 4. Code

Code follows the convention of the respective framework

That also includes the supporting subdomain as in DDD as well as technically relevant packages.

### Supporting Subdomain (Frontend)

- They are shared amongs all apps and are located in `/supporting`.
- They are regular JS packages (eg. Ember Addons)

### Technical Packages (Frontend)

- Location: `/packages`
- They are part of this monorepo to suit the needs in the other locations
- Some are ideally relayed back to their origin and them being used instead of the monorepo clone

## Microservices

These are the auth and API in services/ directory
