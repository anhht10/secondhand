import { getConnectionToken } from '@nestjs/mongoose';
import { Test, TestingModule } from '@nestjs/testing';
import { HealthService } from './health.service';

describe('HealthService', () => {
  let service: HealthService;

  const mockConnection = {
    readyState: 1,
    name: 'remarket',
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        HealthService,
        {
          provide: getConnectionToken(),
          useValue: mockConnection,
        },
      ],
    }).compile();

    service = module.get<HealthService>(HealthService);
  });

  it('returns ok status and connected database state when readyState is 1', () => {
    mockConnection.readyState = 1;
    const status = service.checkHealth();

    expect(status.status).toBe('ok');
    expect(status.service).toBe('remarket-backend');
    expect(status.database.status).toBe('connected');
    expect(status.database.connected).toBe(true);
  });

  it('returns degraded status when database is disconnected', () => {
    mockConnection.readyState = 0;
    const status = service.checkHealth();

    expect(status.status).toBe('degraded');
    expect(status.database.status).toBe('disconnected');
    expect(status.database.connected).toBe(false);
  });
});
