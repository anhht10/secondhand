import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import {
  ApiSuccessResponse,
  PaginatedResult,
} from '../interfaces/api-response.interface';

function isPaginatedResult<T>(value: unknown): value is PaginatedResult<T> {
  return (
    typeof value === 'object' &&
    value !== null &&
    'items' in value &&
    Array.isArray((value as PaginatedResult<T>).items) &&
    'meta' in value &&
    typeof (value as PaginatedResult<T>).meta === 'object'
  );
}

@Injectable()
export class TransformInterceptor<T> implements NestInterceptor<
  T,
  ApiSuccessResponse<unknown>
> {
  intercept(
    _context: ExecutionContext,
    next: CallHandler,
  ): Observable<ApiSuccessResponse<unknown>> {
    return next.handle().pipe(
      map((result) => {
        if (
          typeof result === 'object' &&
          result !== null &&
          'success' in result &&
          (result as Record<string, unknown>).success === true
        ) {
          return result as ApiSuccessResponse<unknown>;
        }

        if (isPaginatedResult(result)) {
          return {
            success: true,
            message: result.message || 'Success',
            data: result.items,
            meta: result.meta,
          };
        }

        if (
          typeof result === 'object' &&
          result !== null &&
          'data' in result &&
          'message' in result &&
          Object.keys(result).length === 2
        ) {
          const wrapped = result as { data: unknown; message: string };
          return {
            success: true,
            message: wrapped.message,
            data: wrapped.data,
            meta: {},
          };
        }

        return {
          success: true,
          message: 'Success',
          data: result ?? {},
          meta: {},
        };
      }),
    );
  }
}
