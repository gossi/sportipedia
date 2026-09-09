import {
  findInstrumentBySlug,
  INSTRUMENTS,
  mockReadInstrument,
  UNICYCLE
} from '#equipment-test-support';
import preview from '#storybook/preview.ts';
import { mockReadInstrumentWithError } from '#tests/equipment/support/queries/instruments.ts';
import { NotFoundError, UnknownError } from '#tests/support/data/errors.ts';

import { InstrumentTemplate } from './instrument.gts';

const meta = preview
  .type<{
    args: {
      model: {
        instrument: string;
      };
      instrument: string;
    };
  }>()
  .meta({
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
  });

// @ts-expect-error csf-next has some troubles with types
export const Default = meta.story({
  // @ts-expect-error csf-next has some troubles with types
  beforeEach({ msw, args }) {
    // eslint-disable-next-line @typescript-eslint/no-unsafe-argument, @typescript-eslint/no-unsafe-member-access
    const instrument = findInstrumentBySlug(args.instrument);

    // eslint-disable-next-line @typescript-eslint/no-unsafe-call, @typescript-eslint/no-unsafe-member-access
    msw.use(
      instrument
        ? mockReadInstrument(instrument)
        : // eslint-disable-next-line @typescript-eslint/no-unsafe-argument, @typescript-eslint/no-unsafe-member-access
          mockReadInstrumentWithError(args.instrument, new NotFoundError())
    );
  }
});

// @ts-expect-error csf-next has some troubles with types
export const Error = meta.story({
  // @ts-expect-error csf-next has some troubles with types
  beforeEach({ msw, args }) {
    // eslint-disable-next-line @typescript-eslint/no-unsafe-call, @typescript-eslint/no-unsafe-member-access
    msw.use(
      // eslint-disable-next-line @typescript-eslint/no-unsafe-argument, @typescript-eslint/no-unsafe-member-access
      mockReadInstrumentWithError(args.instrument, new UnknownError())
    );
  }
});
