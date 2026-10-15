import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { getModelToken } from '@nestjs/mongoose';
import { Test, TestingModule } from '@nestjs/testing';
import * as bcrypt from 'bcrypt';
import { Types } from 'mongoose';
import { UserStatus } from '../users/schemas/user.schema';
import { UsersService } from '../users/users.service';
import { AuthService } from './auth.service';
import { RefreshSession } from './schemas/refresh-session.schema';

describe('AuthService', () => {
  let service: AuthService;

  const mockUserId = new Types.ObjectId();
  const mockUser = {
    _id: mockUserId,
    email: 'khoa@remarket.vn',
    displayName: 'Khoa Nguyen',
    status: UserStatus.ACTIVE,
    passwordHash: '',
  };

  const mockUsersService = {
    create: jest.fn(),
    findByEmailWithPassword: jest.fn(),
    findById: jest.fn(),
    sanitizeUser: jest.fn().mockImplementation((u) => ({
      id: String(u._id),
      email: u.email,
      displayName: u.displayName,
      status: u.status,
    })),
  };

  const mockJwtService = {
    signAsync: jest.fn(),
    verifyAsync: jest.fn(),
  };

  const mockConfigService = {
    get: jest.fn().mockImplementation((key: string) => {
      const map: Record<string, string> = {
        'jwt.accessSecret': 'test-access-secret',
        'jwt.accessExpiresIn': '15m',
        'jwt.refreshSecret': 'test-refresh-secret',
        'jwt.refreshExpiresIn': '7d',
      };
      return map[key];
    }),
  };

  const mockRefreshSessionModel = {
    create: jest.fn(),
    findOne: jest.fn(),
    updateOne: jest.fn(),
    updateMany: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    mockUser.passwordHash = await bcrypt.hash('Password123!', 4);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: UsersService, useValue: mockUsersService },
        { provide: JwtService, useValue: mockJwtService },
        { provide: ConfigService, useValue: mockConfigService },
        {
          provide: getModelToken(RefreshSession.name),
          useValue: mockRefreshSessionModel,
        },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  it('registers a user, hashes password, and issues tokens', async () => {
    mockUsersService.create.mockResolvedValue(mockUser);
    mockJwtService.signAsync
      .mockResolvedValueOnce('access-token-xyz')
      .mockResolvedValueOnce('refresh-token-xyz');
    mockRefreshSessionModel.create.mockResolvedValue({});

    const res = await service.register({
      email: 'khoa@remarket.vn',
      password: 'Password123!',
      displayName: 'Khoa Nguyen',
    });

    expect(mockUsersService.create).toHaveBeenCalledTimes(1);
    expect(res.tokens.accessToken).toBe('access-token-xyz');
    expect(res.tokens.refreshToken).toBe('refresh-token-xyz');
    expect(res.user.email).toBe('khoa@remarket.vn');
  });

  it('authenticates valid login credentials and rejects invalid password', async () => {
    mockUsersService.findByEmailWithPassword.mockResolvedValue(mockUser);
    mockJwtService.signAsync
      .mockResolvedValueOnce('access-token-login')
      .mockResolvedValueOnce('refresh-token-login');
    mockRefreshSessionModel.create.mockResolvedValue({});

    const ok = await service.login({
      email: 'khoa@remarket.vn',
      password: 'Password123!',
    });
    expect(ok.tokens.accessToken).toBe('access-token-login');

    await expect(
      service.login({
        email: 'khoa@remarket.vn',
        password: 'WrongPassword999',
      }),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('rotates refresh token and revokes previous session on refresh', async () => {
    const rawRefreshToken = 'valid-refresh-jwt';
    const tokenHash = await bcrypt.hash(rawRefreshToken, 4);
    const mockSession = {
      jti: 'session-jti-1',
      userId: mockUserId,
      tokenHash,
      isRevoked: false,
      expiresAt: new Date(Date.now() + 60000),
      revokedAt: null,
      save: jest.fn().mockResolvedValue({}),
    };

    mockJwtService.verifyAsync.mockResolvedValue({
      sub: String(mockUserId),
      email: mockUser.email,
      type: 'refresh',
      jti: 'session-jti-1',
    });
    mockRefreshSessionModel.findOne.mockReturnValue({
      select: () => ({ exec: jest.fn().mockResolvedValue(mockSession) }),
    });
    mockUsersService.findById.mockResolvedValue(mockUser);
    mockJwtService.signAsync
      .mockResolvedValueOnce('new-access-jwt')
      .mockResolvedValueOnce('new-refresh-jwt');
    mockRefreshSessionModel.create.mockResolvedValue({});

    const refreshed = await service.refresh({ refreshToken: rawRefreshToken });

    expect(mockSession.isRevoked).toBe(true);
    expect(mockSession.save).toHaveBeenCalled();
    expect(refreshed.tokens.accessToken).toBe('new-access-jwt');
  });

  it('revokes refresh session on logout', async () => {
    mockJwtService.verifyAsync.mockResolvedValue({
      sub: String(mockUserId),
      email: mockUser.email,
      type: 'refresh',
      jti: 'session-jti-1',
    });
    mockRefreshSessionModel.updateOne.mockReturnValue({
      exec: jest.fn().mockResolvedValue({ modifiedCount: 1 }),
    });

    const result = await service.logout(String(mockUserId), 'some-refresh-jwt');
    expect(result).toEqual({ loggedOut: true });
    expect(mockRefreshSessionModel.updateOne).toHaveBeenCalled();
  });
});
