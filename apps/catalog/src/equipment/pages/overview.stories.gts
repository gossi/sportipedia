import { Type } from '@warp-drive/core/types/symbols';
import { http, HttpResponse } from 'msw';

import preview from '#storybook/preview.ts';
import { BALANCE_BEAM, PARALLEL_BARS, RINGS } from '#tests/equipment/support/fixtures/apparatuses';
import { SKATEBOARD, UNICYCLE } from '#tests/equipment/support/fixtures/instruments';

import { OverviewTemplate } from './overview.gts';

import type { Apparatus, Instrument } from '#equipment';

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

const meta = preview.meta({
  title: 'Equipment/Pages/Overview',
  component: OverviewTemplate,
  tags: ['!autodocs'],
  parameters: {
    layout: 'fullscreen'
  }
});

export const Default = meta.story({
  beforeEach({ msw }) {
    msw.use(
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
});

export const Error = meta.story({
  beforeEach({ msw }) {
    msw.use(
      http.get('**/equipment/instruments', serverErrorResponse),
      http.get('**/equipment/apparatuses', serverErrorResponse)
    );
  }
});
