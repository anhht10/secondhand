import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import {
  AuthenticatedUser,
  JwtPayload,
} from '../../../common/interfaces/jwt-payload.interface';
import { UsersService } from '../../users/users.service';
import { UserStatus } from '../../users/schemas/user.schema';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    configService: ConfigService,
    private readonly usersService: UsersService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey:
        configService.get<string>('jwt.accessSecret') ??
        'dev-access-secret-change-in-production-min-32-chars',
    });
  }

  async validate(payload: JwtPayload): Promise<AuthenticatedUser> {
    if (!payload?.sub || payload.type !== 'access') {
      throw new UnauthorizedException('Invalid access token');
    }

    try {
      const user = await this.usersService.findById(payload.sub);
      if (user.status !== UserStatus.ACTIVE) {
        throw new UnauthorizedException('User account is not active');
      }

      return {
        userId: String(user._id),
        email: user.email,
      };
    } catch {
      throw new UnauthorizedException('Invalid or expired access token');
    }
  }
}
