import { ability } from 'ember-ability';

export const getUser = ability(({ services }) => () => {
  return services.auth.user;
});

export const isAuthenticated = ability(({ services }) => () => {
  return services.auth.authenticated;
});
