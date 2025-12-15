import type { ComponentLike } from '@glint/template';

export type Logo = ComponentLike<{
  Element: SVGElement;
}>;

export const Apple: Logo = <template>
  <svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 24 24"><path
      fill="currentColor"
      d="M18.71 19.5c-.83 1.24-1.71
2.45-3.05 2.47c-1.34.03-1.77-.79-3.29-.79c-1.53 0-2
.77-3.27.82c-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52
2.43-2.48 4.12-2.51c1.28-.02 2.5.87 3.29.87c.78 0 2.26-1.07 3.81-.91c.65.03
2.47.26 3.64 1.98c-.09.06-2.17 1.28-2.15 3.81c.03 3.02 2.65 4.03 2.68
4.04c-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5c.13 1.17-.34
2.35-1.04 3.19c-.69.85-1.83 1.51-2.95 1.42c-.15-1.15.41-2.35
1.05-3.11"
    /></svg>
</template>;

export { default as Android } from '~icons/logos/android-icon';
export { default as Archlinux } from '~icons/logos/archlinux';
export { default as Chrome } from '~icons/logos/chrome';
export { default as Debian } from '~icons/logos/debian';
export { default as Fedora } from '~icons/logos/fedora';
export { default as Firefox } from '~icons/logos/firefox';
export { default as FreeBSD } from '~icons/logos/freebsd';
export { default as Github } from '~icons/logos/github-icon';
export { default as Google } from '~icons/logos/google-icon';
export { default as Tux } from '~icons/logos/linux-tux';
export { default as MicrosoftEdge } from '~icons/logos/microsoft-edge';
export { default as Microsoft } from '~icons/logos/microsoft-icon';
export { default as Windows } from '~icons/logos/microsoft-windows-icon';
export { default as Safari } from '~icons/logos/safari';
export { default as Samsung } from '~icons/logos/samsung';
export { default as Ubuntu } from '~icons/logos/ubuntu';
