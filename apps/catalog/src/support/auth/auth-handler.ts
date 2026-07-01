import { auth } from './client';

import type { Context, Handler, NextFn } from '@warp-drive/core/request';

export const AuthHandler: Handler = {
  async request<T>(context: Context, next: NextFn<T>) {
    const headers = new Headers(context.request.headers);

    const { data } = await auth.token();

    if (data) {
      headers.append('Authorization', `Bearer ${data.token}`);
    }

    return next({ ...context.request, headers });
  }
};
