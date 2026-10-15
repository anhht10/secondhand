export interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasNextPage?: boolean;
  hasPrevPage?: boolean;
}

export interface ApiSuccessResponse<T> {
  success: true;
  message: string;
  data: T;
  meta: PaginationMeta | Record<string, unknown>;
}

export interface ApiErrorDetail {
  code: string;
  details: string[];
}

export interface ApiErrorResponse {
  success: false;
  statusCode: number;
  message: string;
  error: ApiErrorDetail;
}

export interface PaginatedResult<T> {
  items: T[];
  meta: PaginationMeta;
  message?: string;
}
