interface JsonApiErrorSource {
  pointer?: string;
  parameter?: string;
  header?: string;
}

export interface JsonApiError {
  id?: string;
  status?: string;
  code?: string;
  title?: string;
  detail?: string;
  source?: JsonApiErrorSource;
  meta?: Record<string, unknown>;
}

export interface JsonApiErrorResponse {
  errors: JsonApiError[];
}
