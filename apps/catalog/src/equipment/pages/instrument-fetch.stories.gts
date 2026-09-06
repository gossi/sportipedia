import { http, HttpResponse } from 'msw';

import { InstrumentFetch } from './instrument-fetch.gts';

import type { Meta, StoryObj } from 'ember-storybook';
import type { MswApi } from 'msw-storybook-addon';

export default {
  title: 'Equipment/Pages/InstrumentFetch',
  component: InstrumentFetch,
  tags: ['vitest', '!autodocs']
} satisfies Meta;

export const Default: StoryObj = {
  beforeEach({ msw }) {
    const worker = msw as MswApi;

    worker.use(
      http.get('/api/instrument', () => {
        return HttpResponse.json({
          name: 'Unicycle',
          description: 'Best vehicle in the world'
        });
      })
    );
  }
};

export const Error: StoryObj = {
  beforeEach({ msw }) {
    const worker = msw as MswApi;

    worker.use(
      http.get('/api/instrument', () => {
        return new HttpResponse(undefined, { status: 500 });
      })
    );
  }
};
