import {
  APPARATUSES,
  INSTRUMENTS,
  mockListApparatuses,
  mockListInstruments
} from '#equipment-test-support';

import { OverviewTemplate } from './overview.gts';

import type { Meta, StoryObj } from 'ember-storybook';

const meta = {
  title: 'Equipment/Pages/Overview',
  component: OverviewTemplate,
  tags: ['!autodocs'],
  parameters: {
    layout: 'fullscreen'
  }
} satisfies Meta;

export default meta;

export const Default: StoryObj = {
  beforeEach({ msw }) {
    msw.use(mockListInstruments(INSTRUMENTS), mockListApparatuses(APPARATUSES));
  }
};
