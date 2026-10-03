import { expect, userEvent, waitFor, within } from 'storybook/test';

import { makeCatalogInstrumentEndpoint, mockCatalogInstrument } from '#equipment-test-support';
import { withValidationError } from '#test-support/msw';

import { CatalogInstrumentTemplate } from './catalog-instrument.gts';

import type { Meta, StoryObj } from 'ember-storybook';

interface InstrumentPageArgs {
  instrument: string;
  model: {
    instrument: string;
  };
}

export default {
  title: 'Equipment/Pages/Catalog Instrument',
  component: CatalogInstrumentTemplate,
  tags: ['!autodocs'],
  decorators: [(story, { args }) => story({ args: { model: { instrument: args.instrument } } })]
} satisfies Meta<InstrumentPageArgs>;

export const Default: StoryObj<InstrumentPageArgs> = {
  beforeEach({ msw }) {
    msw.use(mockCatalogInstrument());
  }
};

export const ValidationError: StoryObj<InstrumentPageArgs> = {
  beforeEach({ msw }) {
    msw.use(withValidationError(makeCatalogInstrumentEndpoint(), { slug: 'slug_exists' }));
  },

  play: async ({ canvasElement }) => {
    const body = canvasElement.ownerDocument.body;
    const canvas = within(body);

    await userEvent.click(await canvas.findByRole('textbox', { name: 'Title' }));
    await userEvent.type(await canvas.findByRole('textbox', { name: 'Title' }), 'parallel-bars');
    await userEvent.click(await canvas.findByRole('button', { name: 'Catalog' }));

    await waitFor(() =>
      expect(canvas.queryByText('Slug is already taken', { exact: true })).toHaveTextContent(
        'Slug is already taken'
      )
    );
  }
};
