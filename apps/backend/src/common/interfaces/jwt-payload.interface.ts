export interface JwtAccessPayload {
  sub: string;
  email: string;
  type: 'access';
}

export interface JwtRefreshPayload {
  sub: string;
  email: string;
  jti: string;
  type: 'refresh';
}

export interface JwtPayload {
  sub: string;
  email: string;
  type: 'access' | 'refresh';
  jti?: string;
}

export interface AuthenticatedUser {
  userId: string;
  email: string;
}
