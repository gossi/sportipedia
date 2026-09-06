import { http, HttpResponse } from 'msw';

export const authHandlers = [
  http.get('http://localhost:3000/token', () => {
    return HttpResponse.json({ token: 'storybook-jwt' });
  }),
  http.get('http://localhost:3000/get-session', () => {
    return HttpResponse.json({ message: 'No session' }, { status: 401 });
  })
];
