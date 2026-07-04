import { expect, test } from 'vitest';

import {
  canArchiveApparatus,
  canCatalogApparatus,
  canEditApparatus
} from '#/domain/equipment/domain-objects/apparatus/abilities';
import { RINGS } from '#tests/equipment/support/fixtures/apparatuses.ts';
import { ADMIN, GUEST, USER } from '#tests/user/support/fixtures';

test('canCatalogApparatus()', () => {
  expect(canCatalogApparatus(GUEST)).toBeFalsy();
  expect(canCatalogApparatus(USER)).toBeTruthy();
  expect(canCatalogApparatus(ADMIN)).toBeTruthy();
});

test('canEditApparatus()', () => {
  expect(canEditApparatus(RINGS, GUEST)).toBeFalsy();
  expect(canEditApparatus(RINGS, USER)).toBeTruthy();
  expect(canEditApparatus(RINGS, ADMIN)).toBeTruthy();
});

test('canArchiveApparatus()', () => {
  expect(canArchiveApparatus(RINGS, GUEST)).toBeFalsy();
  expect(canArchiveApparatus(RINGS, USER)).toBeFalsy();
  expect(canArchiveApparatus(RINGS, ADMIN)).toBeTruthy();
});
