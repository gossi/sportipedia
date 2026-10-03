import { type RequestHandler, type ResponseResolver } from 'msw';
import { HttpHandler, type HttpHandlerInfo, HttpResponse } from 'msw/http';
import { delay } from 'msw/utils/delay';
import { passthrough } from 'msw/utils/passthrough';

import { type ApiError, type FieldErrors, toValidationErrors } from './data/errors.ts';
import { toJsonApiErrorDocument } from './data/jsonapi.ts';

/**
 * Where a request is matched: method + path, exactly as msw's `http.*`
 * factories receive them. Domain test-support modules are the owners of
 * endpoints; response *behavior* lives here.
 */
export interface Endpoint {
  method: HttpHandlerInfo['method'];
  path: HttpHandlerInfo['path'];
}

function toEndpoint(source: Endpoint | RequestHandler): Endpoint {
  if ('kind' in source) {
    if (!(source instanceof HttpHandler)) {
      throw new TypeError('[test-support] only HTTP handlers can be re-mocked');
    }

    const { method, path } = source.info;

    return { method, path };
  }

  return source;
}

/**
 * Creates a handler from an endpoint and a responder — or re-mocks an existing
 * handler (matching preserved, responder replaced). Works with any handler
 * built by msw's `http.*` factories.
 */
export function mock(source: Endpoint | RequestHandler, responder: ResponseResolver) {
  const { method, path } = toEndpoint(source);

  return new HttpHandler(method, path, responder);
}

/*
 * Responders: plain msw `ResponseResolver`s, usable anywhere a resolver fits.
 */

async function respondPending(): Promise<Response> {
  await delay('infinite');

  return HttpResponse.json({});
}

function respondNetworkError(): Response {
  return HttpResponse.error();
}

/** Mak a JSON responder */
export function makeJsonResponder(document: object): ResponseResolver {
  return () => HttpResponse.json(document);
}

/** Make a JSON API error responder */
export function makeErrorResponder(error: ApiError): ResponseResolver {
  return () => HttpResponse.json(toJsonApiErrorDocument(error.error), { status: error.status });
}

/** Keeps the request pending forever (delay mode `"infinite"`). */
export function makePendingResponder(): ResponseResolver {
  return respondPending;
}

/** Fakes a network-level error (request never gets any response). */
export function makeNetworkErrorResponder(): ResponseResolver {
  return respondNetworkError;
}

/** Decorates the request with an error response */
export function withError(source: Endpoint | RequestHandler, error: ApiError): RequestHandler {
  return mock(source, makeErrorResponder(error));
}

/** Decorates the request with a loading response */
export function withLoading(source: Endpoint | RequestHandler): RequestHandler {
  return mock(source, makePendingResponder());
}

// #region Delay

async function respondDelayed(
  source: HttpHandler,
  ms: number,
  info: Parameters<ResponseResolver>[0]
): Promise<Response> {
  await delay(ms);

  const result = await source.run({ request: info.request, requestId: info.requestId });

  return result?.response ?? passthrough();
}

/**
 * Delays the handler's *original* response by `ms`.
 *
 * msw keeps a handler's resolver protected, so instead of reconstructing it we
 * delegate to the handler's public `run()` after the pause — preserving the
 * original behavior (including generator-style resolvers).
 */
export function withDelay(handler: RequestHandler, ms: number): RequestHandler {
  if (!(handler instanceof HttpHandler)) {
    throw new TypeError('[test-support] only HTTP handlers can be delayed');
  }

  return mock(handler, (info) => respondDelayed(handler, ms, info));
}

// #region Validation

export function makeValidationErrorResponder(data: FieldErrors): ResponseResolver {
  return () => HttpResponse.json(toJsonApiErrorDocument(toValidationErrors(data)), { status: 422 });
}

export function withValidationError(
  source: Endpoint | RequestHandler,
  data: FieldErrors
): RequestHandler {
  return mock(source, makeValidationErrorResponder(data));
}
