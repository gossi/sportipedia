import React from 'react';

type TypedocIconScope = 'leaf' | 'all';

/** `leaf`: badge only leaf pages; `all`: additionally badge groups containing a module index */
const APIDOCS_ICON_SCOPE: TypedocIconScope = 'leaf';

const KIND_TAG_PREFIX = 'kind-';
const MODULE_INDEX_TAG = 'api-index-module';

const KIND_STYLE = {
  module: { letter: 'M', color: '#b111c9' },
  enum: { letter: 'E', color: '#7e6f15' },
  variable: { letter: 'V', color: '#4760ec' },
  function: { letter: 'F', color: '#572be7' },
  class: { letter: 'C', color: '#1f70c2' },
  interface: { letter: 'I', color: '#108024' },
  'type-alias': { letter: 'T', color: '#d51270' },
  'entry-point': { letter: 'P', color: '#0f8b8d' }
};

export function TypedocBadge({ kind }: { kind: string }) {
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

function kindTagOf(entry: { tags?: string[] }): string | undefined {
  return entry.tags?.find((tag) => tag.startsWith(KIND_TAG_PREFIX))?.slice(KIND_TAG_PREFIX.length);
}

function isModuleIndexParent(item: { children?: string[] }, api: any): boolean {
  return (
    item.children?.some((id: string) => api.resolveStory(id)?.tags?.includes(MODULE_INDEX_TAG)) ??
    false
  );
}

function withBadge(item: { name: string }, kind: string) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center' }}>
      <TypedocBadge kind={kind} />
      {item.name}
    </span>
  );
}

export function renderLabel(item: any, api: any) {
  if (APIDOCS_ICON_SCOPE === 'all') {
    // groups inherit shared tags from their children (e.g. an all-functions group)
    const inherited = kindTagOf(item);

    if (inherited) {
      return withBadge(item, inherited);
    }

    if (isModuleIndexParent(item, api)) {
      return withBadge(item, 'module');
    }

    return item.name;
  }

  // groups inherit shared tags from their children — only leaves carry their own kind
  if (item.type === 'docs' || item.type === 'story') {
    const kind = kindTagOf(item);

    if (kind) {
      return withBadge(item, kind);
    }
  }

  return item.name;
}
