import { fn, hash } from '@ember/helper';

import { ApiError, UserAgent } from '@sportipedia/ui';
import { getSession } from '@sportipedia/user';
import { Await } from '@warp-drive/ember';
import { formatDateTime, t } from 'ember-intl';
import { resource, resourceFactory } from 'ember-resources';
import { eq, notEq } from 'ember-truth-helpers';

import { revokeSession, revokeSessions, SessionsResource } from '#/domain/user/sessions';

import { Button, Card, Icon, Page } from '@hokulea/ember';

import type { TOC } from '@ember/component/template-only';
import type { Session } from 'ember-better-auth';

const sessionsResource = resourceFactory(() => resource(() => new SessionsResource()));

const DotIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path fill="currentColor" stroke="currentColor" stroke-width="4" d="M24 33a9 9 0 1 0 0-18a9 9 0 0 0 0 18Z"/></svg>`;

const SessionCard: TOC<{ Args: { session: Session } }> = <template>
  <style>
    .user-agent {
      display: flex;
      gap: var(--s0);

      & > * + * {
        border-inline-start: 1px var(--shape-stroke-style) var(--shape-stroke-color);
        padding-inline-start: var(--s0);
      }

      & > div {
        display: grid;
        gap: var(--s-2);
      }

      [part="label"] {
        color: var(--typography-subtle);
        font-weight: 550;
        text-transform: uppercase;
        font-size: var(--ls-1);
        display: block;
      }
    }

    .session-card {
      [part="body"] {
        display: grid;
        gap: var(--s0);
      }
    }

    .status {
      display: grid;
      gap: var(--s-4);

      [part="current-session"] {
        color: var(--indicator-success-plain-text);
      }
    }
  </style>
  {{#let (getSession) as |currentSession|}}
    <Card class="session-card">
      {{#if @session.userAgent}}
        <div class="status">
          {{#if @session.ipAddress}}
            <span>{{@session.ipAddress}}</span>
          {{/if}}

          {{#if (eq @session.token currentSession.token)}}
            <span part="current-session">
              <Icon @icon={{DotIcon}} />
              {{t "user.pages.sessions.current-session"}}
            </span>
          {{else}}
            <span>
              {{t "user.pages.sessions.last-accessed"}}
              {{formatDateTime
                @session.updatedAt
                (hash dateStyle="full" timeStyle="medium")
              }}</span>
          {{/if}}

        </div>
        <div class="user-agent">
          <UserAgent @userAgent={{@session.userAgent}} as |ua|>
            <div>
              <span part="label">Device</span>
              <ua.Device />
            </div>

            <div>
              <span part="label">OS</span>
              <ua.OS />
            </div>

            <div>
              <span part="label">Browser</span>
              <ua.Browser />
            </div>
          </UserAgent>
        </div>
        {{#if (notEq @session.token currentSession.token)}}
          <div class="actions">
            <Button @spacing="-1" @push={{fn revokeSession @session.token}}>
              {{t "user.pages.sessions.actions.revoke-session"}}
            </Button>
          </div>
        {{/if}}
      {{/if}}
    </Card>
  {{/let}}
</template>;

<template>
  <Page @title={{t "user.pages.sessions.title"}}>
    {{#let (sessionsResource) as |sessions|}}
      <Await @promise={{(sessions.load)}}>
        <:pending>
          {{! <Spinner /> }}
        </:pending>

        <:error as |error|>
          <ApiError @error={{error}} />
        </:error>

        <:success>
          <div>
            <Button @push={{sessions.revokeOtherSessions}}>
              {{t "user.pages.sessions.actions.revoke-other-sessions"}}
            </Button>
            <Button @push={{revokeSessions}}>
              {{t "user.pages.sessions.actions.revoke-all-sessions"}}
            </Button>
          </div>

          {{#let (getSession) as |currentSession|}}
            {{#if currentSession}}
              <SessionCard @session={{currentSession}} />
            {{/if}}

            {{#each sessions.sessions as |session|}}
              {{#if (notEq session.token currentSession.token)}}
                <SessionCard @session={{session}} />
              {{/if}}
            {{/each}}
          {{/let}}
        </:success>
      </Await>
    {{/let}}
  </Page>
</template>
