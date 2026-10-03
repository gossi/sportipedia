type AtLeastOne<T, U = { [K in keyof T]: Pick<T, K> }> = Partial<T> & U[keyof U];

export type JsonApiError = AtLeastOne<{
  id: string;
  status: string;
  code: string;
  title: string;
  detail: string;
  source: AtLeastOne<{
    pointer: string;
    parameter: string;
    header: string;
  }>;
  meta: Record<string, unknown>;
}>;

// interface JsonApiErrorSource {
//   pointer?: string;
//   parameter?: string;
//   header?: string;
// }

// export interface JsonApiError {
//   id?: string;
//   status?: string;
//   code?: string;
//   title?: string;
//   detail?: string;
//   source?: JsonApiErrorSource;
//   meta?: Record<string, unknown>;
// }

export interface JsonApiErrorResponse {
  errors: JsonApiError[];
}
