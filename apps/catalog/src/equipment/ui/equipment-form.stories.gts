import { expect, fn, userEvent } from 'storybook/test';

import { EQUIPMENTS, makeEquipmenDecorator, UNICYCLE } from '#equipment-test-support';

import { EquipmentForm } from './equipment-form.gts';

import type { Meta, StoryObj } from 'ember-storybook';

export default {
  title: 'Equipment/UI/EquipmentForm',
  component: EquipmentForm,
  tags: ['!autodocs'],
  argTypes: {
    confirm: {
      table: {
        category: 'Actions'
      }
    }
  },
  args: {
    equipment: UNICYCLE
  },
  decorators: makeEquipmenDecorator(EQUIPMENTS)
} satisfies Meta;

export const Default: StoryObj = {
  args: {
    submit: fn()
  },
  play: async ({ canvas, args }) => {
    await userEvent.type(canvas.getByRole('textbox', { name: 'Title' }), 'abc');
    await expect(canvas.getByRole('textbox', { name: 'Slug' })).toHaveValue('abc');

    await userEvent.type(canvas.getByRole('textbox', { name: 'Title' }), 'def');
    await expect(canvas.getByRole('textbox', { name: 'Slug' })).toHaveValue('abcdef');

    await userEvent.click(canvas.getByRole('button', { name: 'Catalog' }));
    await expect(args.submit).toBeCalled();
  }
};
