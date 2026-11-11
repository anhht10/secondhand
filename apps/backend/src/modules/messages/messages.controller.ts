import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiParam,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ApiErrorResponseDto } from '../../common/dto/api-response.dto';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { ParseObjectIdPipe } from '../../common/pipes/parse-object-id.pipe';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateConversationDto } from './dto/create-conversation.dto';
import { CreateMessageDto } from './dto/create-message.dto';
import { PaginationQueryDto } from './dto/query-messages.dto';
import { MessagesService } from './messages.service';

@ApiTags('Messages & Conversations')
@Controller('messages')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class MessagesController {
  constructor(private readonly messagesService: MessagesService) {}

  @Post('conversations')
  @ApiOperation({
    summary:
      'Start or retrieve a buyer-seller conversation for a specific product listing',
  })
  @ApiResponse({
    status: 201,
    description: 'Conversation created or existing conversation returned',
  })
  @ApiResponse({
    status: 400,
    description: 'Invalid product status or buyer is the product seller',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 404,
    description: 'Product not found',
    type: ApiErrorResponseDto,
  })
  async createConversation(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() createDto: CreateConversationDto,
  ) {
    return this.messagesService.createOrGetConversation(
      currentUser.userId,
      createDto,
    );
  }

  @Get('conversations')
  @ApiOperation({
    summary:
      'List all conversations where the authenticated user is buyer or seller (paginated)',
  })
  @ApiResponse({
    status: 200,
    description: 'Paginated list of user conversations',
  })
  async getConversations(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Query() queryDto: PaginationQueryDto,
  ) {
    return this.messagesService.findUserConversations(
      currentUser.userId,
      queryDto,
    );
  }

  @Get('conversations/:id')
  @ApiOperation({
    summary: 'Get conversation details by ID (participants only)',
  })
  @ApiParam({ name: 'id', description: 'Conversation MongoDB ObjectId' })
  @ApiResponse({ status: 200, description: 'Conversation details returned' })
  @ApiResponse({
    status: 403,
    description: 'Forbidden — user is not a participant of this conversation',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 404,
    description: 'Conversation not found',
    type: ApiErrorResponseDto,
  })
  async getConversationById(
    @Param('id', ParseObjectIdPipe) id: string,
    @CurrentUser() currentUser: AuthenticatedUser,
  ) {
    return this.messagesService.findConversationById(id, currentUser.userId);
  }

  @Get('conversations/:id/messages')
  @ApiOperation({
    summary: 'Get paginated messages for a conversation (participants only)',
  })
  @ApiParam({ name: 'id', description: 'Conversation MongoDB ObjectId' })
  @ApiResponse({ status: 200, description: 'Paginated conversation messages' })
  @ApiResponse({
    status: 403,
    description: 'Forbidden — user is not a participant of this conversation',
    type: ApiErrorResponseDto,
  })
  async getMessages(
    @Param('id', ParseObjectIdPipe) id: string,
    @CurrentUser() currentUser: AuthenticatedUser,
    @Query() queryDto: PaginationQueryDto,
  ) {
    return this.messagesService.getConversationMessages(
      id,
      currentUser.userId,
      queryDto,
    );
  }

  @Post('conversations/:id/messages')
  @ApiOperation({
    summary: 'Send a new message in a conversation (participants only)',
  })
  @ApiParam({ name: 'id', description: 'Conversation MongoDB ObjectId' })
  @ApiResponse({ status: 201, description: 'Message sent' })
  @ApiResponse({
    status: 400,
    description: 'Empty content or archived product',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 403,
    description: 'Forbidden — user is not a participant of this conversation',
    type: ApiErrorResponseDto,
  })
  async sendMessage(
    @Param('id', ParseObjectIdPipe) id: string,
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() createDto: CreateMessageDto,
  ) {
    return this.messagesService.sendMessage(id, currentUser.userId, createDto);
  }

  @Patch(':id/read')
  @ApiOperation({
    summary: 'Mark a message as read (conversation participants only)',
  })
  @ApiParam({ name: 'id', description: 'Message MongoDB ObjectId' })
  @ApiResponse({ status: 200, description: 'Message marked as read' })
  @ApiResponse({
    status: 403,
    description: 'Forbidden — user is not a participant of this conversation',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 404,
    description: 'Message not found',
    type: ApiErrorResponseDto,
  })
  async markAsRead(
    @Param('id', ParseObjectIdPipe) id: string,
    @CurrentUser() currentUser: AuthenticatedUser,
  ) {
    return this.messagesService.markMessageAsRead(id, currentUser.userId);
  }
}
