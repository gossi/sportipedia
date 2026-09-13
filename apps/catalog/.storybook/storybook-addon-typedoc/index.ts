import { definePreviewAddon } from 'storybook/internal/csf';

let guardRegistered = false;

interface PreviewGlobal {
  channel?: { emit: (event: string, payload?: string | null) => void };
}

/**
 * Route typedoc pages' `?path=` links through the manager instead of navigating the window.
 *
 * Storybook does this via its MDXProvider (`a: AnchorMdx`), but under pnpm the compiled MDX,
 * ember-storybook and addon-docs resolve different `@mdx-js/react` copies, so the component
 * mapping never lands. A delegated listener on the preview document gets the same result:
 * unmodified clicks ask the manager to navigate, cmd/middle-clicks still open real URLs.
 */
function registerLinkGuard(): void {
  if (guardRegistered) {
    return;
  }

  guardRegistered = true;

  document.addEventListener('click', (event) => {
    const target = event.target;
    const link =
      target instanceof Element
        ? target.closest('a[href^="?path="], a[href^="./?path="]')
        : undefined;

    if (
      link &&
      event.button === 0 &&
      !event.altKey &&
      !event.ctrlKey &&
      !event.metaKey &&
      !event.shiftKey
    ) {
      event.preventDefault();

      const preview = (globalThis as unknown as { __STORYBOOK_PREVIEW__?: PreviewGlobal })
        .__STORYBOOK_PREVIEW__;

      preview?.channel?.emit('navigateUrl', link.getAttribute('href'));
    }
  });
}

/**
 * Storybook addon for TypeDoc markdown output: reads the generated `.md` pages, turns them into
 * MDX docs pages behind the scenes, and decorates the sidebar with typedoc badges.
 *
 * Server-side options (iconScope, hideIndexPages, ...) are configured on the addon entry in
 * `main.ts`; this preview annotation only marks typedoc pages for the preview runtime.
 */
export default function addonTypedoc() {
  registerLinkGuard();

  return definePreviewAddon({});
}
