import React from 'react';

import type { IconScope } from './types';

const KIND_TAG_PREFIX = 'kind-';
const MODULE_INDEX_TAG = 'api-index-module';

const KIND_STYLE: Record<string, { letter: string; color: string }> = {
  module: { letter: 'M', color: '#b111c9' },
  package: { letter: 'P', color: '#0f8b8d' },
  enum: { letter: 'E', color: '#7e6f15' },
  variable: { letter: 'V', color: '#4760ec' },
  function: { letter: 'F', color: '#572be7' },
  class: { letter: 'C', color: '#1f70c2' },
  interface: { letter: 'I', color: '#108024' },
  'type-alias': { letter: 'T', color: '#d51270' }
};

interface SidebarEntry {
  name: string;
  title?: string;
  type?: string;
  tags?: string[];
  children?: string[];
}

interface SidebarApi {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  resolveStory(id: string): any;
}

function TypedocBadge({ kind }: { kind: string }) {
  const style = KIND_STYLE[kind];

  if (!style) {
    return null;
  }

  return (
    <span
      aria-hidden
      className="typedoc-badge"
      style={{
        backgroundColor: style.color,
        borderRadius: 4,
        color: '#fff',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
        fontSize: 9,
        fontWeight: 700,
        lineHeight: 1,
        height: 14,
        width: 14,
        marginRight: 5
      }}
    >
      {style.letter}
    </span>
  );
}

function kindTagOf(entry: SidebarEntry): string | undefined {
  return entry.tags?.find((tag) => tag.startsWith(KIND_TAG_PREFIX))?.slice(KIND_TAG_PREFIX.length);
}

function isModuleIndexParent(item: SidebarEntry, api: SidebarApi): boolean {
  return (
    item.children?.some((id) => api.resolveStory(id)?.tags?.includes(MODULE_INDEX_TAG)) ?? false
  );
}

/** typedoc docs pages are always named `Docs` in the index — show the leaf of their title */
function labelOf(item: SidebarEntry): string {
  if (item.type === 'docs' && item.name === 'Docs' && item.title) {
    return item.title.split('/').at(-1)!;
  }

  return item.name;
}

function withBadge(item: SidebarEntry, kind: string) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center' }}>
      <TypedocBadge kind={kind} />
      {labelOf(item)}
    </span>
  );
}

export function makeRenderLabel(config: { iconScope: IconScope }) {
  return function renderLabel(item: SidebarEntry, api: SidebarApi) {
    if (config.iconScope === 'all') {
      // groups inherit shared tags from their children (e.g. an all-functions group)
      const inherited = kindTagOf(item);

      if (inherited) {
        return withBadge(item, inherited);
      }

      if (isModuleIndexParent(item, api)) {
        return withBadge(item, 'module');
      }

      return labelOf(item);
    }

    // groups inherit shared tags from their children — only leaves carry their own kind
    if (item.type === 'docs' || item.type === 'story') {
      const kind = kindTagOf(item);

      if (kind) {
        return withBadge(item, kind);
      }
    }

    return labelOf(item);
  };
}
