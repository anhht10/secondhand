import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiBody,
  ApiOperation,
  ApiParam,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import type { Request } from 'express';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ApiErrorResponseDto } from '../../common/dto/api-response.dto';
import { type AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AiRequestContext } from './ai-http.client';
import { AiService } from './ai.service';
import {
  AiChatDto,
  AiChatResponseDto,
  AiConversationHistoryResponseDto,
  AiDeleteConversationResponseDto,
  BuyerChecklistDto,
  BuyerChecklistResponseDto,
  EstimatePriceDto,
  EstimatedPriceResponseDto,
  GenerateListingDto,
  GeneratedListingResponseDto,
} from './dto/ai.dto';

@ApiTags('AI Assistant (Gemini 3.8 Flash + LangGraph)')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('ai')
export class AiController {
  constructor(private readonly aiService: AiService) {}

  private buildRequestContext(
    user: AuthenticatedUser,
    req: Request,
  ): AiRequestContext {
    return {
      userId: user.userId,
      bearerToken:
        typeof req.headers.authorization === 'string'
          ? req.headers.authorization
          : undefined,
      requestId:
        typeof req.headers['x-request-id'] === 'string'
          ? req.headers['x-request-id']
          : undefined,
    };
  }

  @Post('generate-listing')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'AI 1: Generate structured 3-part listing description, title, tags, and transparency note via LangGraph',
  })
  @ApiBody({ type: GenerateListingDto })
  @ApiResponse({
    status: 200,
    description: 'AI-generated listing content returned',
    type: GeneratedListingResponseDto,
  })
  @ApiResponse({
    status: 400,
    description: 'Validation error (VALIDATION_ERROR)',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized (missing or invalid JWT)',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 503,
    description: 'AI Service unavailable (AI_SERVICE_UNAVAILABLE)',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 504,
    description: 'AI Service timeout (AI_REQUEST_TIMEOUT)',
    type: ApiErrorResponseDto,
  })
  async generateListing(
    @CurrentUser() user: AuthenticatedUser,
    @Req() req: Request,
    @Body() dto: GenerateListingDto,
  ) {
    return this.aiService.generateListing(
      dto,
      this.buildRequestContext(user, req),
    );
  }

  @Post('estimate-price')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'AI 2: Estimate 3-tier secondhand market pricing (Quick Sell, Recommended, Max Fair Price) grounded in real comparable products',
  })
  @ApiBody({ type: EstimatePriceDto })
  @ApiResponse({
    status: 200,
    description: '3-tier price estimation and reasoning returned',
    type: EstimatedPriceResponseDto,
  })
  @ApiResponse({
    status: 400,
    description: 'Validation error (VALIDATION_ERROR)',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized (missing or invalid JWT)',
    type: ApiErrorResponseDto,
  })
  async estimatePrice(
    @CurrentUser() user: AuthenticatedUser,
    @Req() req: Request,
    @Body() dto: EstimatePriceDto,
  ) {
    return this.aiService.estimatePrice(
      dto,
      this.buildRequestContext(user, req),
    );
  }

  @Post('buyer-checklist')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'AI 3: Generate or retrieve cached AI Buyer Inspection Checklist & 3 seller questions',
  })
  @ApiBody({ type: BuyerChecklistDto })
  @ApiResponse({
    status: 200,
    description: 'Buyer checklist and suggested questions returned',
    type: BuyerChecklistResponseDto,
  })
  @ApiResponse({
    status: 404,
    description: 'Product not found (PRODUCT_NOT_FOUND)',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized (missing or invalid JWT)',
    type: ApiErrorResponseDto,
  })
  async buyerChecklist(
    @CurrentUser() user: AuthenticatedUser,
    @Req() req: Request,
    @Body() dto: BuyerChecklistDto,
  ) {
    return this.aiService.buyerChecklist(
      dto,
      this.buildRequestContext(user, req),
    );
  }

  @Post('chat')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'AI 4: Multi-turn AI Shopping Assistant Chatbot with persistent thread_id memory and real MongoDB catalog grounding',
  })
  @ApiBody({ type: AiChatDto })
  @ApiResponse({
    status: 200,
    description:
      'Chatbot response with verified active matchedProducts and thread_id',
    type: AiChatResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized (missing or invalid JWT)',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 403,
    description: 'Forbidden (attempting to access another user thread_id)',
    type: ApiErrorResponseDto,
  })
  async chat(
    @CurrentUser() user: AuthenticatedUser,
    @Req() req: Request,
    @Body() dto: AiChatDto,
  ) {
    return this.aiService.chat(dto, this.buildRequestContext(user, req));
  }

  @Get('conversations/:conversationId')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Inspect multi-turn conversation history and session state (strictly isolated to the authenticated owner)',
  })
  @ApiParam({ name: 'conversationId', description: 'Conversation thread_id' })
  @ApiResponse({
    status: 200,
    description: 'Conversation history returned',
    type: AiConversationHistoryResponseDto,
  })
  @ApiResponse({
    status: 403,
    description: 'Forbidden (conversation belongs to another user)',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 404,
    description: 'Conversation not found',
    type: ApiErrorResponseDto,
  })
  async getConversation(
    @CurrentUser() user: AuthenticatedUser,
    @Req() req: Request,
    @Param('conversationId') conversationId: string,
  ) {
    return this.aiService.getConversation(
      conversationId,
      this.buildRequestContext(user, req),
    );
  }

  @Delete('conversations/:conversationId')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Delete a conversation thread and purge its checkpointer state (strictly isolated to the authenticated owner)',
  })
  @ApiParam({ name: 'conversationId', description: 'Conversation thread_id' })
  @ApiResponse({
    status: 200,
    description: 'Conversation deleted',
    type: AiDeleteConversationResponseDto,
  })
  @ApiResponse({
    status: 403,
    description: 'Forbidden (conversation belongs to another user)',
    type: ApiErrorResponseDto,
  })
  async deleteConversation(
    @CurrentUser() user: AuthenticatedUser,
    @Req() req: Request,
    @Param('conversationId') conversationId: string,
  ) {
    return this.aiService.deleteConversation(
      conversationId,
      this.buildRequestContext(user, req),
    );
  }
}
