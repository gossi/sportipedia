import type { JsonApiError, JsonApiErrorResponse } from './jsonapi';
import type { ValidationResult } from '@hokulea/ember';
import type { StandardSchemaV1 } from '@standard-schema/spec';
import type { StructuredErrorDocument } from '@warp-drive/core/types/request';
import type { IntlService } from 'ember-intl';

function jsonPointerToPath(pointer: string): PropertyKey[] {
  if (pointer === '' || pointer === '/') return [];

  // Strip known JSON:API request-document envelope prefixes
  let stripped = pointer;
  const prefixes = ['/data/attributes/', '/data/relationships/', '/data/'];

  for (const p of prefixes) {
    if (stripped.startsWith(p)) {
      stripped = '/' + stripped.slice(p.length);

      break;
    }
  }

  const segments = stripped.replace(/^\//, '').split('/');

  return segments.map((seg) => {
    const unescaped = seg.replaceAll('~1', '/').replaceAll('~0', '~');

    return /^\d+$/.test(unescaped) ? Number(unescaped) : unescaped;
  });
}

export function transformJsonApiErrorsToStandardSchemaIssues(
  errors: JsonApiError[],
  options?: {
    message?: (message: string | undefined) => string;
  }
): StandardSchemaV1.Issue[] {
  const issues: StandardSchemaV1.Issue[] = errors.map((err) => {
    const message = options?.message?.(err.detail) ?? err.detail ?? 'Unknown Error';
    let path: StandardSchemaV1.Issue['path'];

    if (err.source?.pointer) {
      path = jsonPointerToPath(err.source.pointer);
    } else if (err.source?.parameter) {
      path = [err.source.parameter];
    }

    return { message, ...(path && { path }) };
  });

  return issues;
}

export function handleErrorResponse(
  { content }: StructuredErrorDocument<JsonApiErrorResponse>,
  options?: {
    message?: (message: string | undefined) => string;
  }
): ValidationResult | void {
  if (content?.errors) {
    return {
      success: false,
      // @ts-expect-error https://github.com/hokulea/pahu/issues/220
      issues: transformJsonApiErrorsToStandardSchemaIssues(content.errors, options)
    };
  }
}

export function makeMessageTranslator(namespace: string, intl: IntlService) {
  return (message: string | undefined) => {
    const key = `${namespace}.${message}`;

    return intl.exists(key) ? intl.t(key) : intl.t('errors.unknown');
  };
}
