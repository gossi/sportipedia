import { http, HttpResponse } from 'msw';

import {
  findInstrumentBySlug,
  INSTRUMENTS,
  mockReadInstrument,
  UNICYCLE
} from '#equipment-test-support';
import { mockReadInstrumentWithError } from '#tests/equipment/support/queries/instruments.ts';
import { NotFoundError } from '#tests/support/data/errors.ts';

import { InstrumentTemplate } from './instrument.gts';

import type { Meta, StoryObj } from 'ember-storybook';
import type { MswApi } from 'msw-storybook-addon';

interface Args {
  model: {
    instrument: string;
  };
  instrument: string;
}

export default {
  title: 'Equipment/Pages/Instrument',
  component: InstrumentTemplate,
  tags: ['vitest', '!autodocs'],
  parameters: {
    controls: {
      exclude: ['model']
    }
  },
  argTypes: {
    instrument: {
      control: {
        type: 'select',
        labels: Object.fromEntries(INSTRUMENTS.map((e) => [e.slug, e.title]))
      },
      options: INSTRUMENTS.map((i) => i.slug),
      table: {
        category: 'model'
      }
    }
  },
  args: {
    instrument: UNICYCLE.slug
  },
  decorators: [(story, { args }) => story({ args: { model: { instrument: args.instrument } } })]
} satisfies Meta<Args>;

export const Default: StoryObj<Args> = {
  beforeEach({ msw, args }) {
    const worker = msw as MswApi;
    const instrument = findInstrumentBySlug(args.instrument);

    worker.use(
      instrument
        ? mockReadInstrument(instrument)
        : mockReadInstrumentWithError(args.instrument, new NotFoundError())
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
