# Frontend Coding Guidelines

> **See [ARCHITECTURE.md](../ARCHITECTURE.md)** for detailed architecture documentation (C4 Model, DDD, CQRS/ES, directory structures).

## Frameworks & Languages

- **Ember**: Ember Polaris (Ember with vite)
- **Node.js**: TypeScript primarily, with .gts for templates
- **Package Manager**: pnpm (strict)
- **Node Version**: >= 24

## Import Conventions

Virtual path imports (use `#` prefix) for app-local modules:

```typescript
import UserMenu from '#/components/user-menu.gts';
import { auth } from '#/auth';
import { t } from 'ember-intl';
import type { User } from '@sportipedia/user';
```

## File Naming

| File Type | Convention | Example |
|-----------|------------|---------|
| TypeScript | `*.ts` | `auth.ts` |
| Glimmer TS | `*.gts` | `user-menu.gts` |

## Ember Components

### Class Components (.gts)

```typescript
import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { service } from '@ember/service';

export default class MyComponent extends Component<Args> {
  @tracked data: SomeData | null = null;
  @service declare auth: AuthService;

  <template>
    <div>{{@title}}</div>
  </template>
}
```

### Template-Only Components (.gts)

```typescript
import type { TOC } from '@ember/component/template-only';

const MyComponent: TOC<{ Args: { title: string } }> = <template>
  <div>{{@title}}</div>
</template>;

export default MyComponent;
```

### State Management

- `@glimmer/tracking` with `@tracked` for reactive state
- `ember-resources` for async data:

  ```typescript
  import { resource } from 'ember-resources';
  const userResource = resource(async () => await fetchUser());
  ```

- `@warp-drive/core` Store for data/cache

## TypeScript Guidelines

- Explicit types for function arguments and return types
- Use `type` for aliases, interfaces for objects
- Import types separately
- Avoid `any`, use `unknown` when type is unknown

## Error Handling

Use try/catch, display via `ApiError` component.

## CSS and Styling

- **ember-scoped-css** for component-scoped styles
- **Stylelint** for CSS linting (follows stylelint-config-standard)

## Linting

- **Ember**: ESLint, Prettier, Stylelint, Template Lint

## Important Patterns

1. **Registry services**: `buildRegistry({ 'service:auth': AuthService })`
2. **Link navigation**: `import { link } from 'ember-link';`
3. **Page titles**: `import { pageTitle } from 'ember-page-title';`
4. **i18n**: `import { t } from 'ember-intl';`

## Notes

- Use `pnpm` (not `npm` or `yarn`) for Node.js
- Follow Ember Octane patterns (classic Ember patterns deprecated)
- Use `@ember/service` for services
- Use Glimmer components for new components
- Run `pnpm lint:types` before committing (Node.js)
