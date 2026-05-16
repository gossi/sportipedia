# Coding Guidelines for Ember

- **Ember**: Ember Polaris (Ember with vite)

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

## CSS and Styling

- **ember-scoped-css** for component-scoped styles
- **Stylelint** for CSS linting
