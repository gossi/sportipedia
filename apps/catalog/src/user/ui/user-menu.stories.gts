import { AppHeader } from '@hokulea/ember';

import { UserMenu } from './user-menu.gts';

import type { Meta, StoryObj } from 'ember-storybook';

export default {
  title: 'User/UI/UserMenu',
  component: UserMenu,
  parameters: {
    layout: 'fullscreen'
  },
  render: () => <template>
    <AppHeader>
      <:brand>Sportipedia</:brand>
      <:aux as |nav|>
        <UserMenu @nav={{nav}} />
      </:aux>
    </AppHeader>
  </template>,
  tags: ['!autodocs']
} satisfies Meta;

export const Basic: StoryObj = {};
