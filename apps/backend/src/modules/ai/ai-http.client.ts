import {
  BadGatewayException,
  BadRequestException,
  ForbiddenException,
  GatewayTimeoutException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';

export interface AiRequestContext {
  userId?: string;
  bearerToken?: string;
  requestId?: string;
}

@Injectable()
export class AiHttpClient {
  private readonly logger = new Logger(AiHttpClient.name);

  constructor(private readonly configService: ConfigService) {}

  get baseUrl(): string {
    return (
      this.configService.get<string>('ai.serviceUrl') ||
      process.env.AI_SERVICE_URL ||
      'http://localhost:8000'
    )
      .trim()
      .replace(/\/+$/, '');
  }

  get timeoutMs(): number {
    const configured = this.configService.get<number>('ai.timeoutMs');
    if (typeof configured === 'number' && configured > 0) {
      return configured;
    }
    const envVal = parseInt(process.env.AI_REQUEST_TIMEOUT_MS || '15000', 10);
    return Number.isFinite(envVal) && envVal > 0 ? envVal : 15000;
  }

  get serviceToken(): string {
    return (
      this.configService.get<string>('ai.serviceToken') ||
      process.env.AI_SERVICE_TOKEN ||
      process.env.BACKEND_SERVICE_TOKEN ||
      ''
    ).trim();
  }

  resolveRequestId(context?: AiRequestContext): string {
    const candidate = context?.requestId?.trim();
    return candidate && candidate.length > 0
      ? candidate
      : `req-${randomUUID().replace(/-/g, '').slice(0, 16)}`;
  }

  async post<T>(
    endpointPath: string,
    body: unknown,
    context?: AiRequestContext,
  ): Promise<T> {
    return this.request<T>('POST', endpointPath, body, context);
  }

  async get<T>(endpointPath: string, context?: AiRequestContext): Promise<T> {
    return this.request<T>('GET', endpointPath, undefined, context);
  }

  async delete<T>(
    endpointPath: string,
    context?: AiRequestContext,
  ): Promise<T> {
    return this.request<T>('DELETE', endpointPath, undefined, context);
  }

  private async request<T>(
    method: 'GET' | 'POST' | 'DELETE',
    endpointPath: string,
    body?: unknown,
    context?: AiRequestContext,
  ): Promise<T> {
    const requestId = this.resolveRequestId(context);
    const normalizedPath = endpointPath.startsWith('/')
      ? endpointPath
      : `/${endpointPath}`;
    const url = `${this.baseUrl}${normalizedPath}`;

    const headers: Record<string, string> = {
      Accept: 'application/json',
      'X-Request-ID': requestId,
    };

    if (body !== undefined) {
      headers['Content-Type'] = 'application/json';
    }

    if (context?.userId) {
      headers['X-Authenticated-User-Id'] = context.userId;
    }

    if (context?.bearerToken) {
      const rawToken = context.bearerToken.trim();
      headers['Authorization'] = rawToken.toLowerCase().startsWith('bearer ')
        ? rawToken
        : `Bearer ${rawToken}`;
    }

    const internalToken = this.serviceToken;
    if (internalToken) {
      headers['X-Internal-Service-Token'] = internalToken;
    }

    const controller = new AbortController();
    const timeoutHandle = setTimeout(() => controller.abort(), this.timeoutMs);
    const startTime = Date.now();

    try {
      const response = await fetch(url, {
        method,
        headers,
        body: body !== undefined ? JSON.stringify(body) : undefined,
        signal: controller.signal,
      });

      const elapsedMs = Date.now() - startTime;
      this.logger.log(
        `[${requestId}] ${method} ${normalizedPath} -> status=${response.status} latency=${elapsedMs}ms user=${context?.userId ?? 'anonymous'}`,
      );

      const rawText = await response.text();
      let parsedBody: unknown = null;
      if (rawText && rawText.trim().length > 0) {
        try {
          parsedBody = JSON.parse(rawText);
        } catch {
          if (response.ok) {
            throw new BadGatewayException({
              code: 'AI_INVALID_RESPONSE',
              message: 'AI Service returned malformed JSON response',
              requestId,
            });
          }
        }
      }

      if (!response.ok) {
        this.throwMappedHttpError(response.status, parsedBody, requestId);
      }

      if (!parsedBody || typeof parsedBody !== 'object') {
        throw new BadGatewayException({
          code: 'AI_INVALID_RESPONSE',
          message: 'AI Service returned an empty or invalid response payload',
          requestId,
        });
      }

      return parsedBody as T;
    } catch (error) {
      if (error instanceof HttpException) {
        throw error;
      }

      const err = error as Error & { name?: string; code?: string };
      const isTimeout =
        err?.name === 'AbortError' ||
        err?.name === 'TimeoutError' ||
        /abort|timed?\s*out/i.test(err?.message || '');

      if (isTimeout) {
        this.logger.warn(
          `[${requestId}] AI Service request timed out after ${this.timeoutMs}ms (${method} ${normalizedPath})`,
        );
        throw new GatewayTimeoutException({
          code: 'AI_REQUEST_TIMEOUT',
          message: 'AI Service request timed out',
          requestId,
        });
      }

      this.logger.warn(
        `[${requestId}] AI Service unreachable (${method} ${normalizedPath}): ${err?.message || 'Network error'}`,
      );
      throw new ServiceUnavailableException({
        code: 'AI_SERVICE_UNAVAILABLE',
        message: 'AI Service is currently unavailable',
        requestId,
      });
    } finally {
      clearTimeout(timeoutHandle);
    }
  }

  private throwMappedHttpError(
    status: number,
    parsedBody: unknown,
    requestId: string,
  ): never {
    const obj =
      parsedBody && typeof parsedBody === 'object'
        ? (parsedBody as Record<string, unknown>)
        : {};
    const errObj =
      obj.error && typeof obj.error === 'object'
        ? (obj.error as Record<string, unknown>)
        : {};

    const upstreamCode =
      typeof errObj.code === 'string'
        ? errObj.code
        : typeof obj.code === 'string'
          ? obj.code
          : '';
    const upstreamMessage =
      typeof obj.message === 'string' && obj.message.trim().length > 0
        ? obj.message.trim()
        : typeof obj.detail === 'string' && obj.detail.trim().length > 0
          ? obj.detail.trim()
          : 'AI Service request failed';
    const upstreamDetails = Array.isArray(errObj.details)
      ? errObj.details.map((d) => String(d))
      : undefined;

    if (status === 400 || status === 422) {
      throw new BadRequestException({
        code: 'VALIDATION_ERROR',
        message: upstreamMessage,
        details: upstreamDetails ?? [upstreamMessage],
        requestId,
      });
    }

    if (status === 401) {
      throw new UnauthorizedException({
        code: 'UNAUTHORIZED',
        message: upstreamMessage || 'Unauthorized AI Service request',
        requestId,
      });
    }

    if (status === 403) {
      throw new ForbiddenException({
        code: 'FORBIDDEN',
        message:
          upstreamMessage ||
          'You do not have permission to access this AI resource',
        requestId,
      });
    }

    if (status === 404) {
      const code =
        upstreamCode === 'BACKEND_NOT_FOUND' ||
        upstreamCode === 'PRODUCT_NOT_FOUND'
          ? 'PRODUCT_NOT_FOUND'
          : 'NOT_FOUND';
      throw new NotFoundException({
        code,
        message: upstreamMessage || 'Requested resource was not found',
        requestId,
      });
    }

    if (status === 429) {
      throw new HttpException(
        {
          code: 'AI_RATE_LIMITED',
          message:
            upstreamMessage ||
            'AI rate limit exceeded. Please wait before sending more requests.',
          requestId,
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    if (status === 504) {
      throw new GatewayTimeoutException({
        code: 'AI_REQUEST_TIMEOUT',
        message: upstreamMessage || 'AI Service request timed out',
        requestId,
      });
    }

    if (status === 503) {
      throw new ServiceUnavailableException({
        code: 'AI_SERVICE_UNAVAILABLE',
        message: upstreamMessage || 'AI Service is currently unavailable',
        requestId,
      });
    }

    throw new BadGatewayException({
      code: 'AI_INVALID_RESPONSE',
      message: upstreamMessage || 'Invalid response from AI Service',
      requestId,
    });
  }
}
