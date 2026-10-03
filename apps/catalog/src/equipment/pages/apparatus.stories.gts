import {
  APPARATUSES,
  findApparatusBySlug,
  makeReadApparatusEndpoint,
  mockReadApparatus,
  PARALLEL_BARS
} from '#equipment-test-support';
import { NotFoundError, UnknownError } from '#test-support/data/errors.ts';
import { withError, withLoading } from '#test-support/msw';

import { ApparatusTemplate } from './apparatus.gts';

import type { Meta, StoryObj } from 'ember-storybook';

interface ApparatusPageArgs {
  apparatus: string;
  model: {
    apparatus: string;
  };
}

export default {
  title: 'Equipment/Pages/Apparatus',
  component: ApparatusTemplate,
  tags: ['!autodocs'],
  parameters: {
    controls: {
      exclude: ['model']
    }
  },
  argTypes: {
    apparatus: {
      control: {
        type: 'select',
        labels: Object.fromEntries(APPARATUSES.map((e) => [e.slug, e.title]))
      },
      options: APPARATUSES.map((i) => i.slug),
      table: {
        category: 'model'
      }
    }
  },
  args: {
    apparatus: PARALLEL_BARS.slug
  },
  decorators: [(story, { args }) => story({ args: { model: { apparatus: args.apparatus } } })]
} satisfies Meta<ApparatusPageArgs>;

export const Default: StoryObj<ApparatusPageArgs> = {
  beforeEach({ msw, args }) {
    const apparatus = findApparatusBySlug(args.apparatus);

    msw.use(
      apparatus
        ? mockReadApparatus(apparatus)
        : withError(makeReadApparatusEndpoint(args.apparatus), new NotFoundError())
    );
  }
};

export const Error: StoryObj<ApparatusPageArgs> = {
  beforeEach({ msw, args }) {
    msw.use(withError(makeReadApparatusEndpoint(args.apparatus), new UnknownError()));
  }
};

export const Loading: StoryObj<ApparatusPageArgs> = {
  beforeEach({ msw, args }) {
    msw.use(withLoading(makeReadApparatusEndpoint(args.apparatus)));
  }
};
