import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const request = ctx.getRequest<Request>();
    const response = ctx.getResponse<Response>();

    let statusCode = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';
    let code = 'INTERNAL_SERVER_ERROR';
    let details: string[] = [];
    let requestId: string | undefined =
      typeof request?.headers?.['x-request-id'] === 'string'
        ? request.headers['x-request-id']
        : undefined;

    if (exception instanceof HttpException) {
      statusCode = exception.getStatus();
      const exceptionResponse = exception.getResponse();

      if (typeof exceptionResponse === 'string') {
        message = exceptionResponse;
        details = [exceptionResponse];
        code = this.mapStatusToCode(statusCode, false);
      } else if (
        typeof exceptionResponse === 'object' &&
        exceptionResponse !== null
      ) {
        const resObj = exceptionResponse as Record<string, unknown>;
        const rawMessage = resObj.message;
        const customCode =
          typeof resObj.code === 'string' && resObj.code.trim().length > 0
            ? resObj.code.trim()
            : typeof (resObj.error as Record<string, unknown> | undefined)
                  ?.code === 'string'
              ? String((resObj.error as Record<string, unknown>).code).trim()
              : undefined;

        if (typeof resObj.requestId === 'string' && resObj.requestId.trim()) {
          requestId = resObj.requestId.trim();
        }

        if (Array.isArray(rawMessage)) {
          details = rawMessage.map((m) => String(m));
          message = details[0] || 'Validation failed';
          code =
            customCode ||
            (statusCode === HttpStatus.BAD_REQUEST
              ? 'VALIDATION_ERROR'
              : this.mapStatusToCode(statusCode, true));
        } else if (typeof rawMessage === 'string') {
          message = rawMessage;
          details = Array.isArray(resObj.details)
            ? resObj.details.map((d) => String(d))
            : [rawMessage];
          code = customCode || this.mapStatusToCode(statusCode, false);
        } else {
          message = exception.message || 'Error';
          details = Array.isArray(resObj.details)
            ? resObj.details.map((d) => String(d))
            : [message];
          code = customCode || this.mapStatusToCode(statusCode, false);
        }
      }
    } else if (
      typeof exception === 'object' &&
      exception !== null &&
      ((exception as Record<string, unknown>).name === 'MulterError' ||
        typeof (exception as Record<string, unknown>).code === 'string')
    ) {
      const errObj = exception as {
        name?: string;
        code?: string;
        message?: string;
      };
      if (
        errObj.name === 'MulterError' ||
        errObj.code === 'LIMIT_FILE_SIZE' ||
        errObj.code === 'LIMIT_FILE_COUNT' ||
        errObj.code === 'LIMIT_UNEXPECTED_FILE'
      ) {
        statusCode = HttpStatus.BAD_REQUEST;
        message = errObj.message || 'File upload validation error';
        code = 'VALIDATION_ERROR';
        details = [message];
      } else {
        this.logger.error('Unhandled error occurred', errObj.message);
      }
    } else if (
      typeof exception === 'object' &&
      exception !== null &&
      (exception as Record<string, unknown>).code === 11000
    ) {
      statusCode = HttpStatus.CONFLICT;
      message = 'Duplicate resource value violates unique constraint';
      code = 'CONFLICT';
      details = [message];
    } else {
      this.logger.error(
        'Unhandled exception occurred',
        exception instanceof Error ? exception.message : 'Unknown error',
      );
      details = ['An unexpected error occurred'];
    }

    if (requestId && !response.getHeader('X-Request-ID')) {
      response.setHeader('X-Request-ID', requestId);
    }

    response.status(statusCode).json({
      success: false,
      statusCode,
      message,
      error: {
        code,
        details,
        ...(requestId ? { requestId } : {}),
      },
    });
  }

  private mapStatusToCode(
    statusCode: number,
    isValidationArray: boolean,
  ): string {
    if (statusCode === HttpStatus.BAD_REQUEST && isValidationArray) {
      return 'VALIDATION_ERROR';
    }
    switch (statusCode) {
      case HttpStatus.BAD_REQUEST:
        return 'BAD_REQUEST';
      case HttpStatus.UNAUTHORIZED:
        return 'UNAUTHORIZED';
      case HttpStatus.FORBIDDEN:
        return 'FORBIDDEN';
      case HttpStatus.NOT_FOUND:
        return 'NOT_FOUND';
      case HttpStatus.CONFLICT:
        return 'CONFLICT';
      case HttpStatus.PAYLOAD_TOO_LARGE:
        return 'PAYLOAD_TOO_LARGE';
      case HttpStatus.TOO_MANY_REQUESTS:
        return 'TOO_MANY_REQUESTS';
      case HttpStatus.BAD_GATEWAY:
        return 'AI_INVALID_RESPONSE';
      case HttpStatus.SERVICE_UNAVAILABLE:
        return 'AI_SERVICE_UNAVAILABLE';
      case HttpStatus.GATEWAY_TIMEOUT:
        return 'AI_REQUEST_TIMEOUT';
      default:
        return HttpStatus[statusCode] || 'INTERNAL_SERVER_ERROR';
    }
  }
}
