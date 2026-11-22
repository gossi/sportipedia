import { expect, test } from 'vitest';

import {
  canArchiveWidget,
  canCreateWidget,
  canEditWidget,
  canNoteWidget,
  canRelabelWidget
} from '#/equipment/domain-objects/widget/abilities';
import { CLASSIC_WIDGET } from '#equipment-test-support';
import { ADMIN, GUEST, USER } from '#tests/user/support/fixtures';

test('canArchiveWidget()', () => {
  expect(canArchiveWidget(CLASSIC_WIDGET, ADMIN)).toBeTruthy();
  expect(canArchiveWidget(CLASSIC_WIDGET, GUEST)).toBeFalsy();
  expect(canArchiveWidget(CLASSIC_WIDGET, USER)).toBeTruthy();
});

test('canCreateWidget()', () => {
  expect(canCreateWidget(ADMIN)).toBeTruthy();
  expect(canCreateWidget(GUEST)).toBeFalsy();
  expect(canCreateWidget(USER)).toBeTruthy();
});

test('canEditWidget()', () => {
  expect(canEditWidget(CLASSIC_WIDGET, ADMIN)).toBeTruthy();
  expect(canEditWidget(CLASSIC_WIDGET, GUEST)).toBeFalsy();
  expect(canEditWidget(CLASSIC_WIDGET, USER)).toBeTruthy();
});

test('canNoteWidget()', () => {
  expect(canNoteWidget(CLASSIC_WIDGET, ADMIN)).toBeTruthy();
  expect(canNoteWidget(CLASSIC_WIDGET, GUEST)).toBeFalsy();
  expect(canNoteWidget(CLASSIC_WIDGET, USER)).toBeTruthy();
});

test('canRelabelWidget()', () => {
  expect(canRelabelWidget(CLASSIC_WIDGET, ADMIN)).toBeTruthy();
  expect(canRelabelWidget(CLASSIC_WIDGET, GUEST)).toBeFalsy();
  expect(canRelabelWidget(CLASSIC_WIDGET, USER)).toBeTruthy();
});

