import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { getModelToken } from '@nestjs/mongoose';
import { Test, TestingModule } from '@nestjs/testing';
import { Types } from 'mongoose';
import { Product, ProductStatus } from '../products/schemas/product.schema';
import { User, UserStatus } from '../users/schemas/user.schema';
import { MessagesService } from './messages.service';
import { Conversation } from './schemas/conversation.schema';
import { Message, MessageType } from './schemas/message.schema';

describe('MessagesService', () => {
  let service: MessagesService;

  const buyerId = new Types.ObjectId();
  const sellerId = new Types.ObjectId();
  const outsiderId = new Types.ObjectId();
  const productId = new Types.ObjectId();
  const conversationId = new Types.ObjectId();
  const messageId = new Types.ObjectId();

  const mockConversation = {
    _id: conversationId,
    buyerId,
    sellerId,
    productId,
    lastMessage: 'Hello',
    lastMessageAt: new Date(),
  };

  const mockMessage = {
    _id: messageId,
    conversationId,
    senderId: buyerId,
    content: 'Hello',
    messageType: MessageType.TEXT,
    isRead: false,
    createdAt: new Date(),
    save: jest.fn().mockResolvedValue(true),
  };

  const mockConversationModel = {
    findOne: jest.fn(),
    create: jest.fn(),
    find: jest.fn(),
    findById: jest.fn(),
    countDocuments: jest.fn(),
    updateOne: jest.fn(),
    deleteMany: jest.fn(),
  };

  const mockMessageModel = {
    create: jest.fn(),
    find: jest.fn(),
    findById: jest.fn(),
    countDocuments: jest.fn(),
    deleteMany: jest.fn(),
  };

  const mockProductModel = {
    findById: jest.fn(),
  };

  const mockUserModel = {
    findById: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MessagesService,
        {
          provide: getModelToken(Conversation.name),
          useValue: mockConversationModel,
        },
        {
          provide: getModelToken(Message.name),
          useValue: mockMessageModel,
        },
        {
          provide: getModelToken(Product.name),
          useValue: mockProductModel,
        },
        {
          provide: getModelToken(User.name),
          useValue: mockUserModel,
        },
      ],
    }).compile();

    service = module.get<MessagesService>(MessagesService);
  });

  it('prevents a seller from creating a conversation with themselves', async () => {
    mockUserModel.findById.mockReturnValue({
      lean: () => ({
        exec: jest.fn().mockResolvedValue({
          _id: sellerId,
          status: UserStatus.ACTIVE,
        }),
      }),
    });
    mockProductModel.findById.mockReturnValue({
      lean: () => ({
        exec: jest.fn().mockResolvedValue({
          _id: productId,
          sellerId,
          status: ProductStatus.ACTIVE,
        }),
      }),
    });

    await expect(
      service.createOrGetConversation(String(sellerId), {
        productId: String(productId),
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('blocks non-participants from accessing a conversation with 403 Forbidden', async () => {
    mockConversationModel.findById.mockReturnValue({
      populate: () => ({
        populate: () => ({
          populate: () => ({
            exec: jest.fn().mockResolvedValue(mockConversation),
          }),
        }),
      }),
    });

    await expect(
      service.findConversationById(String(conversationId), String(outsiderId)),
    ).rejects.toThrow(ForbiddenException);

    const allowed = await service.findConversationById(
      String(conversationId),
      String(buyerId),
    );
    expect(String(allowed._id)).toBe(String(conversationId));
  });

  it('marks message as read for conversation participants and rejects non-participants', async () => {
    mockMessageModel.findById.mockReturnValue({
      exec: jest
        .fn()
        .mockResolvedValue({ ...mockMessage, isRead: false, save: jest.fn() }),
      populate: () => ({
        exec: jest.fn().mockResolvedValue({ ...mockMessage, isRead: true }),
      }),
    });
    mockConversationModel.findById.mockReturnValue({
      exec: jest.fn().mockResolvedValue(mockConversation),
    });

    await expect(
      service.markMessageAsRead(String(messageId), String(outsiderId)),
    ).rejects.toThrow(ForbiddenException);

    const updated = await service.markMessageAsRead(
      String(messageId),
      String(sellerId),
    );
    expect(updated.isRead).toBe(true);
  });

  it('throws NotFoundException on invalid conversation ID', async () => {
    await expect(
      service.findConversationById('invalid-id', String(buyerId)),
    ).rejects.toThrow(NotFoundException);
  });
});
