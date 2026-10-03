/**
 * @module Public API
 * @mergeModuleWith user
 */
import { buildRegistry } from 'ember-strict-application-resolver/build-registry';

import { buildRoutes } from '#/support/routing';

import { LoginTemplate } from './pages/login.gts';
import { LogoutRoute } from './pages/logout';
import { RegistrationTemplate } from './pages/registration.gts';
import { RequestPasswordResetTemplate } from './pages/request-password-reset.gts';
import { ResetPasswordTemplate } from './pages/reset-password.gts';
import { UserRoute, UserTemplate } from './pages/user.gts';
import { ApperanceTemplate } from './pages/user/appearance.gts';
import { AuthTemplate } from './pages/user/auth.gts';
import { ProfileTemplate } from './pages/user/profile.gts';
import { SessionsTemplate } from './pages/user/sessions.gts';

// Modules

/**
 * @internal
 */
export const userRegistry = buildRegistry({
  './routes/logout': LogoutRoute,
  './routes/user': UserRoute,

  './templates/user/auth': AuthTemplate,
  './templates/user/appearance': ApperanceTemplate,
  './templates/user/profile': ProfileTemplate,
  './templates/user/sessions': SessionsTemplate,
  './templates/login': LoginTemplate,
  './templates/registration': RegistrationTemplate,
  './templates/request-password-reset': RequestPasswordResetTemplate,
  './templates/reset-password': ResetPasswordTemplate,
  './templates/user': UserTemplate
});

// Routes

/**
 * @internal
 */
export const userRoutes = buildRoutes(function () {
  /* eslint-disable @typescript-eslint/no-invalid-this, unicorn/no-this-outside-of-class */
  this.route('login');
  this.route('logout');
  this.route('registration');
  this.route('request-password-reset');
  this.route('reset-password');
  this.route('user', function () {
    this.route('profile');
    this.route('appearance');
    this.route('sessions');
    this.route('auth');
  });
  /* eslint-enable @typescript-eslint/no-invalid-this, unicorn/no-this-outside-of-class */
});

// UI

export { UserMenu } from './ui/user-menu.gts';

// Settings

/**
 * @category Public API
 */
export { changeLocale, persistLanguage, renderLocale } from './domain-objects/language';
