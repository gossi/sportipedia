import type { JsonApiError } from '#support/data/jsonapi.ts';

export interface ApiError {
  status: number;
  error: JsonApiError;
}

export class PlainApiError implements ApiError {
  status: number;
  protected _error: JsonApiError;

  constructor(status: number, error: JsonApiError) {
    this.status = status;
    this._error = error;
  }

  get error(): JsonApiError {
    return { ...this._error, status: String(this.status) };
  }
}

export class NotFoundError extends PlainApiError {
  constructor() {
    super(404, { title: 'Not found' });
  }
}

export class UnauthorizedError extends PlainApiError {
  constructor() {
    super(403, {
      title: 'Forbidden',
      detail: 'You do not have permission to perform this action'
    });
  }
}
