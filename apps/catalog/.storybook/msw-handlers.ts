import { http, HttpResponse } from 'msw/http';

export const authHandlers = [
  http.get('**/token', () => {
    return HttpResponse.json({ token: 'storybook-jwt' });
  }),
  http.get('**/get-session', () => {
    return HttpResponse.json({ message: 'No session' }, { status: 401 });
  })
];
