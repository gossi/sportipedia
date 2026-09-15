import { userEvent, within, waitFor, expect } from 'storybook/test';
import { Counter } from './counter.gts';

import type { Meta, StoryObj } from 'ember-storybook';

export default {
  title: 'Counter',
  component: Counter,
  tags: ['!autodocs']
} satisfies Meta;

export const Basic: StoryObj = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement.ownerDocument.body);
    await userEvent.click(await canvas.findByRole('button', { name: '+' }));
    await userEvent.click(await canvas.findByRole('button', { name: '+' }));
    await userEvent.click(await canvas.findByRole('button', { name: '+' }));
    await userEvent.click(await canvas.findByRole('button', { name: '-' }));
    await waitFor(() => expect(canvas.queryByText('Counter: 2', { exact: true })).toHaveTextContent('Counter: 2'));
  }
};
