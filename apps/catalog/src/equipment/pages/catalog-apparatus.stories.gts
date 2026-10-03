import { expect, userEvent, waitFor, within } from 'storybook/test';

import { makeCatalogApparatusEndpoint, mockCatalogApparatus } from '#equipment-test-support';
import { withValidationError } from '#test-support/msw';

import { CatalogApparatusTemplate } from './catalog-apparatus.gts';

import type { Meta, StoryObj } from 'ember-storybook';

interface ApparatusPageArgs {
  apparatus: string;
  model: {
    apparatus: string;
  };
}

export default {
  title: 'Equipment/Pages/Catalog Apparatus',
  component: CatalogApparatusTemplate,
  tags: ['!autodocs'],
  decorators: [(story, { args }) => story({ args: { model: { apparatus: args.apparatus } } })]
} satisfies Meta<ApparatusPageArgs>;

export const Default: StoryObj<ApparatusPageArgs> = {
  beforeEach({ msw }) {
    msw.use(mockCatalogApparatus());
  }
};

export const ValidationError: StoryObj<ApparatusPageArgs> = {
  beforeEach({ msw }) {
    msw.use(withValidationError(makeCatalogApparatusEndpoint(), { slug: 'slug_exists' }));
  },

  play: async ({ canvasElement }) => {
    const body = canvasElement.ownerDocument.body;
    const canvas = within(body);

    await userEvent.click(await canvas.findByRole('textbox', { name: 'Title' }));
    await userEvent.type(await canvas.findByRole('textbox', { name: 'Title' }), 'unicycle');
    await userEvent.click(await canvas.findByRole('button', { name: 'Catalog' }));

    await waitFor(() =>
      expect(canvas.queryByText('Slug is already taken', { exact: true })).toHaveTextContent(
        'Slug is already taken'
      )
    );
  }
};
