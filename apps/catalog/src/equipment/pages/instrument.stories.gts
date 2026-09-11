import {
  findInstrumentBySlug,
  INSTRUMENTS,
  makeInstrumentEndpoint,
  mockReadInstrument,
  UNICYCLE
} from '#equipment-test-support';
import { NotFoundError, UnknownError } from '#test-support/data/errors.ts';
import { withError, withLoading } from '#test-support/msw';

import { InstrumentTemplate } from './instrument.gts';

import type { Meta, StoryObj } from 'ember-storybook';

interface InstrumentPageArgs {
  instrument: string;
  model: {
    instrument: string;
  };
}

export default {
  title: 'Equipment/Pages/Instrument',
  component: InstrumentTemplate,
  tags: ['!autodocs'],
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
} satisfies Meta<InstrumentPageArgs>;

export const Default: StoryObj<InstrumentPageArgs> = {
  beforeEach({ msw, args }) {
    const instrument = findInstrumentBySlug(args.instrument);

    msw.use(
      instrument
        ? mockReadInstrument(instrument)
        : withError(makeInstrumentEndpoint(args.instrument), new NotFoundError())
    );
  }
};

export const Error: StoryObj<InstrumentPageArgs> = {
  beforeEach({ msw, args }) {
    msw.use(withError(makeInstrumentEndpoint(args.instrument), new UnknownError()));
  }
};

export const Loading: StoryObj<InstrumentPageArgs> = {
  beforeEach({ msw, args }) {
    msw.use(withLoading(makeInstrumentEndpoint(args.instrument)));
  }
};
