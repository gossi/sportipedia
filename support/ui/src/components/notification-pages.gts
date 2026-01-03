import PhCheckCircleLight from '~icons/ph/check-circle-light';
import PhXCircleLight from '~icons/ph/x-circle-light';

import { FocusPage, Icon, type IconAsset } from '@hokulea/ember';

import type { TOC } from '@ember/component/template-only';

interface InternalNotificationPageSignature {
  Element: HTMLDivElement;
  Args: {
    icon: IconAsset;
    title?: string;
  };
  Blocks: {
    title?: [];
    content?: [];
    actions?: [];
  };
}

const InternalNotificationPage: TOC<InternalNotificationPageSignature> = <template>
  <style scoped>
    .layout {
      display: flex;
      flex-direction: column;
      gap: calc(var(--s4) * 1.5);
      align-items: center;

      :global(hgroup) {
        display: grid;
        gap: var(--s2);
        justify-items: center;

        :global(span) {
          font-size: calc(var(--s4) * 1.8);
        }
      }

      &[data-indicator="error"] :is(:global(hgroup span), :global(p)) {
        color: var(--indicator-error-plain-text);
      }

      &[data-indicator="success"] :global(hgroup span) {
        color: var(--indicator-success-plain-text);
      }
    }
  </style>
  <FocusPage>
    {{!-- <:description>
      {{#if (has-block "description")}}
        {{yield to="description"}}
      {{else if @description}}
        {{@description}}
      {{/if}}
    </:description> --}}
    <:content>
      <div class="layout" ...attributes>
        <hgroup>
          <Icon @icon={{@icon}} />

          <h1>
            {{#if (has-block "title")}}
              {{yield to="title"}}
            {{else if @title}}
              {{@title}}
            {{/if}}
          </h1>
        </hgroup>

        <p>
          {{#if (has-block "content")}}
            {{yield to="content"}}
          {{/if}}
        </p>

        <div>
          {{yield to="actions"}}
        </div>
      </div>
    </:content>
  </FocusPage>
</template>;

interface NotificationPageSignature {
  Element: HTMLElement;
  Args: {
    title?: string;
  };
  Blocks: {
    title?: [];
    content?: [];
    actions?: [];
  };
}

export const SuccessPage: TOC<NotificationPageSignature> = <template>
  <InternalNotificationPage @icon={{PhCheckCircleLight}} data-indicator="success">
    <:title>
      {{#if (has-block "title")}}
        {{yield to="title"}}
      {{else if @title}}
        {{@title}}
      {{/if}}
    </:title>
    <:content>
      {{#if (has-block "content")}}
        {{yield to="content"}}
      {{else if (has-block)}}
        {{yield}}
      {{/if}}
    </:content>
    <:actions>
      {{yield to="actions"}}
    </:actions>
  </InternalNotificationPage>
</template>;

export const ErrorPage: TOC<NotificationPageSignature> = <template>
  <InternalNotificationPage @icon={{PhXCircleLight}} data-indicator="error">
    <:title>
      {{#if (has-block "title")}}
        {{yield to="title"}}
      {{else if @title}}
        {{@title}}
      {{/if}}
    </:title>
    <:content>
      {{#if (has-block "content")}}
        {{yield to="content"}}
      {{else if (has-block)}}
        {{yield}}
      {{/if}}
    </:content>
    <:actions>
      {{yield to="actions"}}
    </:actions>
  </InternalNotificationPage>
</template>;
