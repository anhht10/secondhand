import {
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectModel } from '@nestjs/mongoose';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';
import { Model, Types } from 'mongoose';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { parseDurationToMs } from '../../common/utils/duration.util';
import { UserDocument, UserStatus } from '../users/schemas/user.schema';
import { UsersService } from '../users/users.service';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RegisterDto } from './dto/register.dto';
import {
  RefreshSession,
  RefreshSessionDocument,
} from './schemas/refresh-session.schema';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: string;
}

export interface AuthResponse {
  user: Record<string, unknown>;
  tokens: AuthTokens;
}

@Injectable()
export class AuthService {
  private readonly bcryptSaltRounds = 10;

  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    @InjectModel(RefreshSession.name)
    private readonly refreshSessionModel: Model<RefreshSessionDocument>,
  ) {}

  async register(registerDto: RegisterDto): Promise<AuthResponse> {
    const passwordHash = await bcrypt.hash(
      registerDto.password,
      this.bcryptSaltRounds,
    );

    const user = await this.usersService.create({
      email: registerDto.email,
      passwordHash,
      displayName: registerDto.displayName,
      phoneNumber: registerDto.phoneNumber ?? null,
      location: registerDto.location ?? null,
      university: registerDto.university ?? null,
    });

    const tokens = await this.issueTokensAndPersistSession(user);

    return {
      user: this.usersService.sanitizeUser(user),
      tokens,
    };
  }

  async login(loginDto: LoginDto): Promise<AuthResponse> {
    const user = await this.usersService.findByEmailWithPassword(
      loginDto.email,
    );

    if (!user) {
      throw new UnauthorizedException('Invalid email or password');
    }

    if (user.status !== UserStatus.ACTIVE) {
      throw new ForbiddenException('User account is not active');
    }

    const isPasswordValid = await bcrypt.compare(
      loginDto.password,
      user.passwordHash,
    );

    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const tokens = await this.issueTokensAndPersistSession(user);

    return {
      user: this.usersService.sanitizeUser(user),
      tokens,
    };
  }

  async refresh(refreshTokenDto: RefreshTokenDto): Promise<AuthResponse> {
    const refreshSecret =
      this.configService.get<string>('jwt.refreshSecret') ??
      'dev-refresh-secret-change-in-production-min-32-chars';

    let payload: JwtPayload;
    try {
      payload = await this.jwtService.verifyAsync<JwtPayload>(
        refreshTokenDto.refreshToken,
        { secret: refreshSecret },
      );
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    if (payload.type !== 'refresh' || !payload.jti || !payload.sub) {
      throw new UnauthorizedException('Invalid refresh token payload');
    }

    const session = await this.refreshSessionModel
      .findOne({ jti: payload.jti })
      .select('+tokenHash')
      .exec();

    if (!session || session.isRevoked || session.expiresAt < new Date()) {
      throw new UnauthorizedException('Refresh session is invalid or revoked');
    }

    const matchesHash = await bcrypt.compare(
      refreshTokenDto.refreshToken,
      session.tokenHash,
    );

    if (!matchesHash) {
      session.isRevoked = true;
      session.revokedAt = new Date();
      await session.save();
      throw new UnauthorizedException('Invalid refresh token');
    }

    const user = await this.usersService.findById(payload.sub);
    if (user.status !== UserStatus.ACTIVE) {
      throw new ForbiddenException('User account is not active');
    }

    // Rotate refresh session: revoke current session and issue a fresh pair
    session.isRevoked = true;
    session.revokedAt = new Date();
    await session.save();

    const tokens = await this.issueTokensAndPersistSession(user);

    return {
      user: this.usersService.sanitizeUser(user),
      tokens,
    };
  }

  async logout(
    userId: string,
    refreshToken?: string,
  ): Promise<{ loggedOut: boolean }> {
    if (refreshToken) {
      const refreshSecret =
        this.configService.get<string>('jwt.refreshSecret') ??
        'dev-refresh-secret-change-in-production-min-32-chars';

      try {
        const payload = await this.jwtService.verifyAsync<JwtPayload>(
          refreshToken,
          { secret: refreshSecret },
        );

        if (payload.jti) {
          await this.refreshSessionModel
            .updateOne(
              { jti: payload.jti, userId: new Types.ObjectId(userId) },
              { $set: { isRevoked: true, revokedAt: new Date() } },
            )
            .exec();
          return { loggedOut: true };
        }
      } catch {
        // Fallback to revoking all active sessions for the user
      }
    }

    await this.refreshSessionModel
      .updateMany(
        { userId: new Types.ObjectId(userId), isRevoked: false },
        { $set: { isRevoked: true, revokedAt: new Date() } },
      )
      .exec();

    return { loggedOut: true };
  }

  async getMe(userId: string): Promise<Record<string, unknown>> {
    if (typeof this.usersService.getMeWithStats === 'function') {
      return this.usersService.getMeWithStats(userId);
    }
    const user = await this.usersService.findById(userId);
    return this.usersService.sanitizeUser(user);
  }

  private async issueTokensAndPersistSession(
    user: UserDocument,
  ): Promise<AuthTokens> {
    const userId = String(user._id);
    const jti = randomUUID();

    const accessSecret =
      this.configService.get<string>('jwt.accessSecret') ??
      'dev-access-secret-change-in-production-min-32-chars';
    const accessExpiresIn =
      this.configService.get<string>('jwt.accessExpiresIn') ?? '15m';
    const refreshSecret =
      this.configService.get<string>('jwt.refreshSecret') ??
      'dev-refresh-secret-change-in-production-min-32-chars';
    const refreshExpiresIn =
      this.configService.get<string>('jwt.refreshExpiresIn') ?? '7d';

    const accessPayload: JwtPayload = {
      sub: userId,
      email: user.email,
      type: 'access',
    };

    const refreshPayload: JwtPayload = {
      sub: userId,
      email: user.email,
      type: 'refresh',
      jti,
    };

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(accessPayload, {
        secret: accessSecret,
        expiresIn: accessExpiresIn as `${number}${'s' | 'm' | 'h' | 'd'}`,
      }),
      this.jwtService.signAsync(refreshPayload, {
        secret: refreshSecret,
        expiresIn: refreshExpiresIn as `${number}${'s' | 'm' | 'h' | 'd'}`,
      }),
    ]);

    const tokenHash = await bcrypt.hash(refreshToken, this.bcryptSaltRounds);
    const expiresAt = new Date(
      Date.now() + parseDurationToMs(refreshExpiresIn),
    );

    await this.refreshSessionModel.create({
      userId: new Types.ObjectId(userId),
      jti,
      tokenHash,
      expiresAt,
      isRevoked: false,
    });

    return {
      accessToken,
      refreshToken,
      expiresIn: accessExpiresIn,
    };
  }
}
