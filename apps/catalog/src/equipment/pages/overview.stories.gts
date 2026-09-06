import { Type } from '@warp-drive/core/types/symbols';
import { http, HttpResponse } from 'msw';

import { BALANCE_BEAM, PARALLEL_BARS, RINGS } from '#tests/equipment/support/fixtures/apparatuses';
import { SKATEBOARD, UNICYCLE } from '#tests/equipment/support/fixtures/instruments';

import { OverviewTemplate } from './overview.gts';

import type { Apparatus, Instrument } from '#equipment';
import type { Meta, StoryObj } from 'ember-storybook';
import type { MswApi } from 'msw-storybook-addon';

function toResource(equipment: Instrument | Apparatus) {
  return {
    type: equipment[Type],
    id: equipment.id,
    attributes: {
      title: equipment.title,
      slug: equipment.slug,
      description: equipment.description,
      createdAt: equipment.createdAt.toString(),
      updatedAt: equipment.updatedAt.toString()
    }
  };
}

function serverErrorResponse() {
  return HttpResponse.json(
    { errors: [{ title: 'Internal Server Error', status: '500' }] },
    { status: 500 }
  );
}

export default {
  title: 'Equipment/Pages/Overview',
  component: OverviewTemplate,
  tags: ['vitest', '!autodocs'],
  parameters: {
    layout: 'fullscreen'
  }
} satisfies Meta;

export const Default: StoryObj = {
  beforeEach({ msw }) {
    const worker = msw as MswApi;

    worker.use(
      http.get('**/equipment/instruments', () => {
        return HttpResponse.json({
          data: [UNICYCLE, SKATEBOARD].map((instrument) => toResource(instrument))
        });
      }),
      http.get('**/equipment/apparatuses', () => {
        return HttpResponse.json({
          data: [PARALLEL_BARS, BALANCE_BEAM, RINGS].map((apparatus) => toResource(apparatus))
        });
      })
    );
  }
};

export const Error: StoryObj = {
  beforeEach({ msw }) {
    const worker = msw as MswApi;

    worker.use(
      http.get('**/equipment/instruments', serverErrorResponse),
      http.get('**/equipment/apparatuses', serverErrorResponse)
    );
  }
};
