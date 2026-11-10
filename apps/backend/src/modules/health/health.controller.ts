import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { HealthService } from './health.service';

@ApiTags('Health')
@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get()
  @ApiOperation({
    summary: 'Check API and MongoDB health status',
    description:
      'Returns service liveness, uptime, and MongoDB connection status.',
  })
  @ApiResponse({
    status: 200,
    description: 'Service and database health report',
  })
  getHealth() {
    return this.healthService.checkHealth();
  }
}
