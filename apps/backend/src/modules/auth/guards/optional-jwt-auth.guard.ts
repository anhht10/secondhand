import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/**
 * Optional JWT guard for public endpoints (such as GET /api/v1/products/:id)
 * that behave slightly differently when accessed by the authenticated resource owner.
 */
@Injectable()
export class OptionalJwtAuthGuard extends AuthGuard('jwt') {
  override canActivate(context: ExecutionContext) {
    return super.canActivate(context);
  }

  override handleRequest<TUser = unknown>(
    _err: unknown,
    user: TUser,
  ): TUser | null {
    return user || null;
  }
}
