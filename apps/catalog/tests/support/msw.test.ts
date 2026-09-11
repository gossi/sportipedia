import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';

import { NotFoundError } from '#tests/support/data/errors.ts';

import { makeErrorResponse, mock, withDelay, withError } from './msw.ts';

const url = 'http://localhost:3000/catalog/equipment/instruments/unicycle';

function okHandler() {
  return http.get('**/catalog/equipment/instruments/unicycle', () =>
    HttpResponse.json({ data: { id: '1' } })
  );
}

describe('mock()', () => {
  it('re-mocks a native msw handler, preserving its matching', async () => {
    const remocked = mock(okHandler(), makeErrorResponse(new NotFoundError()));

    const result = await remocked.run({ request: new Request(url), requestId: 'test' });

    expect(result?.response?.status).toBe(404);
    await expect(result?.response?.json()).resolves.toEqual({
      errors: [{ title: 'Not found', status: '404' }]
    });
  });

  it('does not match unrelated requests', async () => {
    const remocked = withError(okHandler(), new NotFoundError());

    const result = await remocked.run({
      request: new Request('http://localhost:3000/catalog/equipment/instruments/skateboard'),
      requestId: 'test'
    });

    expect(result).toBeNull();
  });
});

describe('remockDelayed()', () => {
  it('preserves the original response after the pause', async () => {
    const delayed = withDelay(okHandler(), 10);

    const result = await delayed.run({ request: new Request(url), requestId: 'test' });

    expect(result?.response?.status).toBe(200);
    await expect(result?.response?.json()).resolves.toEqual({ data: { id: '1' } });
  });
});
