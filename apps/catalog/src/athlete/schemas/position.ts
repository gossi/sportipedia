import { withDefaults } from '@warp-drive/legacy/model/migration-support';

/**
 * Positions are modeled in LegacyMode because PolarisMode does not yet
 * support relationship fields (see warp-drive.io PolarisMode limitations).
 *
 * `rawSlug` is intentionally absent: the API keeps the raw slug out of the
 * representation, exposing only the canonical `slug`.
 */
export const positionSchema = withDefaults({
  type: 'position',
  fields: [
    { kind: 'attribute', name: 'title' },
    { kind: 'attribute', name: 'description' },
    { kind: 'attribute', name: 'slug' },
    // Many positions -> one apparatus/instrument (mutually exclusive).
    // inverse: null keeps these unidirectional so the equipment schemas
    // can stay in PolarisMode; the "many" side is loaded via queries.
    {
      kind: 'belongsTo',
      name: 'apparatus',
      type: 'apparatus',
      // eslint-disable-next-line unicorn/no-null -- WarpDrive requires an explicit null inverse to mark the relationship unidirectional
      options: { async: false, inverse: null }
    },
    {
      kind: 'belongsTo',
      name: 'instrument',
      type: 'instrument',
      // eslint-disable-next-line unicorn/no-null -- WarpDrive requires an explicit null inverse to mark the relationship unidirectional
      options: { async: false, inverse: null }
    }
  ],
  traits: ['timestamps']
});
