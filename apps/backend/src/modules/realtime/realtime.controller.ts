import {
  Controller,
  Get,
  MessageEvent,
  Query,
  Sse,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import { Observable } from 'rxjs';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RealtimeService } from './realtime.service';

@ApiTags('Realtime')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@SkipThrottle()
@Controller('realtime')
export class RealtimeController {
  constructor(private readonly realtimeService: RealtimeService) {}

  @Get('sync')
  @ApiOperation({
    summary:
      'Lightweight in-memory real-time delta sync for messages, orders, payments & notifications',
  })
  syncEvents(
    @CurrentUser() user: AuthenticatedUser,
    @Query('since') since?: string,
  ) {
    const sinceTs = since ? Number(since) : 0;
    return this.realtimeService.getEventsSince(user.userId, sinceTs);
  }

  @Sse('stream')
  @ApiOperation({
    summary:
      'Server-Sent Events (SSE) real-time stream for messages and order updates',
  })
  streamEvents(
    @CurrentUser() user: AuthenticatedUser,
  ): Observable<MessageEvent> {
    return this.realtimeService.subscribeForUser(user.userId);
  }
}
