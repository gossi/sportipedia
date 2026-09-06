import { http, HttpResponse } from 'msw';

import { readInstrumentMock } from '#tests/equipment/support/index.ts';
import { SKATEBOARD, UNICYCLE } from '#tests/equipment/support/fixtures/instruments.ts';

import { InstrumentTemplate } from './instrument.gts';

import type { Meta, StoryObj } from 'ember-storybook';
import type { MswApi } from 'msw-storybook-addon';

export default {
  title: 'Equipment/Pages/Instrument',
  component: InstrumentTemplate,
  tags: ['vitest', '!autodocs'],
  argTypes: {
    instrument: {
      control: {
        type: 'select',
        labels: Object.fromEntries(
          [UNICYCLE, SKATEBOARD].map((instrument) => [instrument.id, instrument])
        )
      }
    }
  }
} satisfies Meta;

export const Default: StoryObj = {
  beforeEach({ msw, args }) {
    const worker = msw as MswApi;

    console.log(args);

    worker.use(
      readInstrumentMock(UNICYCLE)
      // http.get<{ id: string }>('**/equipment/instrument/:id', ({ params }) => {
      //   const instrument = [UNICYCLE, SKATEBOARD].find((ins) => ins.id === params.id);

      //   if (instrument) {
      //     return HttpResponse.json(toResource(instrument));
      //   }

      //   return HttpResponse.json({
      //     name: 'Unicycle',
      //     description: 'Best vehicle in the world'
      //   });
      // })
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
