import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { FilterQuery, Model, Types } from 'mongoose';
import { PaginationMeta } from '../../common/interfaces/api-response.interface';
import {
  Product,
  ProductDocument,
  ProductStatus,
} from '../products/schemas/product.schema';
import { RealtimeService } from '../realtime/realtime.service';
import { User, UserDocument, UserStatus } from '../users/schemas/user.schema';
import { CreateConversationDto } from './dto/create-conversation.dto';
import { CreateMessageDto } from './dto/create-message.dto';
import { PaginationQueryDto } from './dto/query-messages.dto';
import {
  Conversation,
  ConversationDocument,
} from './schemas/conversation.schema';
import {
  Message,
  MessageDocument,
  MessageType,
} from './schemas/message.schema';

export interface PaginatedConversationsResult {
  items: Array<ConversationDocument | Record<string, unknown>>;
  meta: PaginationMeta;
}

export interface PaginatedMessagesResult {
  items: MessageDocument[];
  meta: PaginationMeta;
}

@Injectable()
export class MessagesService {
  constructor(
    @InjectModel(Conversation.name)
    private readonly conversationModel: Model<ConversationDocument>,
    @InjectModel(Message.name)
    private readonly messageModel: Model<MessageDocument>,
    @InjectModel(Product.name)
    private readonly productModel: Model<ProductDocument>,
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
    @Optional()
    private readonly realtimeService?: RealtimeService,
  ) {}

  async createOrGetConversation(
    buyerId: string,
    createDto: CreateConversationDto,
  ): Promise<ConversationDocument> {
    if (!Types.ObjectId.isValid(createDto.productId)) {
      throw new NotFoundException('Product not found');
    }

    const [buyer, product] = await Promise.all([
      this.userModel.findById(buyerId).lean().exec(),
      this.productModel.findById(createDto.productId).lean().exec(),
    ]);

    if (!buyer || buyer.status !== UserStatus.ACTIVE) {
      throw new ForbiddenException('Buyer account is not active');
    }

    if (!product) {
      throw new NotFoundException('Product listing not found');
    }

    if (
      product.status === ProductStatus.DRAFT ||
      product.status === ProductStatus.ARCHIVED
    ) {
      throw new BadRequestException(
        'Cannot start a conversation on a draft or archived product listing',
      );
    }

    const sellerIdStr = String(product.sellerId);
    if (String(buyerId) === sellerIdStr) {
      throw new BadRequestException(
        'Seller cannot start a conversation with themselves on their own product',
      );
    }

    const seller = await this.userModel.findById(sellerIdStr).lean().exec();
    if (!seller || seller.status !== UserStatus.ACTIVE) {
      throw new BadRequestException('Seller account is not available');
    }

    const buyerObjId = new Types.ObjectId(buyerId);
    const sellerObjId = new Types.ObjectId(sellerIdStr);
    const productObjId = new Types.ObjectId(createDto.productId);

    let conversation = await this.conversationModel
      .findOne({
        buyerId: buyerObjId,
        sellerId: sellerObjId,
        productId: productObjId,
      })
      .exec();

    if (!conversation) {
      try {
        conversation = await this.conversationModel.create({
          buyerId: buyerObjId,
          sellerId: sellerObjId,
          productId: productObjId,
          lastMessage: null,
          lastMessageAt: null,
        });
      } catch (err) {
        // Handle concurrent duplicate creation gracefully via unique compound index
        if ((err as { code?: number })?.code === 11000) {
          conversation = await this.conversationModel
            .findOne({
              buyerId: buyerObjId,
              sellerId: sellerObjId,
              productId: productObjId,
            })
            .exec();
        } else {
          throw err;
        }
      }
    }

    if (!conversation) {
      throw new BadRequestException('Unable to initialize conversation');
    }

    if (
      createDto.initialMessage &&
      createDto.initialMessage.trim().length > 0
    ) {
      await this.sendMessage(String(conversation._id), buyerId, {
        content: createDto.initialMessage.trim(),
        messageType: MessageType.TEXT,
      });
    }

    return this.findConversationById(String(conversation._id), buyerId);
  }

  async findUserConversations(
    userId: string,
    queryDto: PaginationQueryDto,
  ): Promise<PaginatedConversationsResult> {
    const page = Math.max(1, queryDto.page ?? 1);
    const limit = Math.min(100, Math.max(1, queryDto.limit ?? 20));
    const skip = (page - 1) * limit;

    const userObjId = new Types.ObjectId(userId);
    const filter: FilterQuery<ConversationDocument> = {
      $or: [{ buyerId: userObjId }, { sellerId: userObjId }],
    };

    const [items, total] = await Promise.all([
      this.conversationModel
        .find(filter)
        .sort({ lastMessageAt: -1, updatedAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate(
          'buyerId',
          'displayName avatarUrl location isEmailVerified status',
        )
        .populate(
          'sellerId',
          'displayName avatarUrl location isEmailVerified status',
        )
        .populate('productId', 'title price condition status images location')
        .exec(),
      this.conversationModel.countDocuments(filter).exec(),
    ]);

    const enrichedItems = await Promise.all(
      items.map(async (conv) => {
        let unreadCount = 0;
        if (typeof this.messageModel.countDocuments === 'function') {
          const countRes = this.messageModel.countDocuments({
            conversationId: conv._id,
            isRead: false,
            senderId: { $ne: userObjId },
          });
          unreadCount =
            typeof (countRes as { exec?: () => Promise<number> })?.exec ===
            'function'
              ? await countRes.exec()
              : await (countRes as unknown as Promise<number>);
        }
        const rawObj =
          typeof (conv as { toJSON?: () => Record<string, unknown> }).toJSON ===
          'function'
            ? conv.toJSON()
            : (conv as unknown as Record<string, unknown>);
        return {
          ...rawObj,
          id: String(conv._id),
          unreadCount: Number(unreadCount) || 0,
          hasUnread: (Number(unreadCount) || 0) > 0,
        };
      }),
    );

    const totalPages = Math.ceil(total / limit) || 1;

    return {
      items: enrichedItems,
      meta: {
        total,
        page,
        limit,
        totalPages,
        hasNextPage: page < totalPages,
        hasPrevPage: page > 1,
      },
    };
  }

  async findConversationById(
    conversationId: string,
    userId: string,
  ): Promise<ConversationDocument> {
    if (!Types.ObjectId.isValid(conversationId)) {
      throw new NotFoundException('Conversation not found');
    }

    const conversation = await this.conversationModel
      .findById(conversationId)
      .populate(
        'buyerId',
        'displayName avatarUrl location isEmailVerified status',
      )
      .populate(
        'sellerId',
        'displayName avatarUrl location isEmailVerified status',
      )
      .populate('productId', 'title price condition status images location')
      .exec();

    if (!conversation) {
      throw new NotFoundException('Conversation not found');
    }

    if (!this.isParticipant(conversation, userId)) {
      throw new ForbiddenException(
        'You do not have permission to access this conversation',
      );
    }

    return conversation;
  }

  async getConversationMessages(
    conversationId: string,
    userId: string,
    queryDto: PaginationQueryDto,
  ): Promise<PaginatedMessagesResult> {
    await this.findConversationById(conversationId, userId);

    const page = Math.max(1, queryDto.page ?? 1);
    const limit = Math.min(100, Math.max(1, queryDto.limit ?? 20));
    const skip = (page - 1) * limit;

    const filter: FilterQuery<MessageDocument> = {
      conversationId: new Types.ObjectId(conversationId),
    };

    const [items, total] = await Promise.all([
      this.messageModel
        .find(filter)
        .sort({ createdAt: 1, _id: 1 })
        .skip(skip)
        .limit(limit)
        .populate('senderId', 'displayName avatarUrl')
        .exec(),
      this.messageModel.countDocuments(filter).exec(),
    ]);

    if (typeof this.messageModel.updateMany === 'function') {
      const updateRes = this.messageModel.updateMany(
        {
          conversationId: new Types.ObjectId(conversationId),
          senderId: { $ne: new Types.ObjectId(userId) },
          isRead: false,
        },
        { $set: { isRead: true } },
      );
      if (
        typeof (updateRes as { exec?: () => Promise<unknown> })?.exec ===
        'function'
      ) {
        await updateRes.exec();
      }
    }

    const totalPages = Math.ceil(total / limit) || 1;

    return {
      items,
      meta: {
        total,
        page,
        limit,
        totalPages,
        hasNextPage: page < totalPages,
        hasPrevPage: page > 1,
      },
    };
  }

  async sendMessage(
    conversationId: string,
    senderId: string,
    createDto: CreateMessageDto,
  ): Promise<MessageDocument> {
    const conversation = await this.findConversationById(
      conversationId,
      senderId,
    );

    const trimmedContent = createDto.content?.trim();
    if (!trimmedContent || trimmedContent.length === 0) {
      throw new BadRequestException('Message content cannot be empty');
    }

    const sender = await this.userModel.findById(senderId).lean().exec();
    if (!sender || sender.status !== UserStatus.ACTIVE) {
      throw new ForbiddenException('Sender account is not active');
    }

    const productId =
      (conversation.productId as unknown as { _id?: Types.ObjectId })?._id ??
      conversation.productId;
    const product = await this.productModel.findById(productId).lean().exec();
    if (!product || product.status === ProductStatus.ARCHIVED) {
      throw new BadRequestException(
        'Cannot send messages for an archived or removed product listing',
      );
    }

    const now = new Date();
    const message = await this.messageModel.create({
      conversationId: new Types.ObjectId(conversationId),
      senderId: new Types.ObjectId(senderId),
      content: trimmedContent,
      messageType: createDto.messageType ?? MessageType.TEXT,
      isRead: false,
    });

    await this.conversationModel
      .updateOne(
        { _id: conversation._id },
        {
          $set: {
            lastMessage: trimmedContent,
            lastMessageAt: message.createdAt ?? now,
          },
        },
      )
      .exec();

    const populated = await this.messageModel
      .findById(message._id)
      .populate('senderId', 'displayName avatarUrl')
      .exec();

    const buyerIdStr = String(
      (conversation.buyerId as unknown as { _id?: Types.ObjectId })?._id ??
        conversation.buyerId,
    );
    const sellerIdStr = String(
      (conversation.sellerId as unknown as { _id?: Types.ObjectId })?._id ??
        conversation.sellerId,
    );
    this.realtimeService?.emitToUsers([buyerIdStr, sellerIdStr], {
      type: 'MESSAGE_CREATED',
      conversationId: String(conversation._id),
      productId: String(productId),
    });

    return populated ?? message;
  }

  async markMessageAsRead(
    messageId: string,
    userId: string,
  ): Promise<MessageDocument> {
    if (!Types.ObjectId.isValid(messageId)) {
      throw new NotFoundException('Message not found');
    }

    const message = await this.messageModel.findById(messageId).exec();
    if (!message) {
      throw new NotFoundException('Message not found');
    }

    const conversation = await this.conversationModel
      .findById(message.conversationId)
      .exec();

    if (!conversation) {
      throw new NotFoundException('Parent conversation not found');
    }

    if (!this.isParticipant(conversation, userId)) {
      throw new ForbiddenException(
        'You do not have permission to mark this message as read',
      );
    }

    if (!message.isRead) {
      message.isRead = true;
      await message.save();
    }

    const populated = await this.messageModel
      .findById(message._id)
      .populate('senderId', 'displayName avatarUrl')
      .exec();

    return populated ?? message;
  }

  async deleteConversationsByProductId(productId: string): Promise<void> {
    if (!Types.ObjectId.isValid(productId)) return;

    const productObjId = new Types.ObjectId(productId);
    const conversations = await this.conversationModel
      .find({ productId: productObjId })
      .select('_id')
      .lean()
      .exec();

    if (conversations.length === 0) return;

    const conversationIds = conversations.map((c) => c._id);
    await Promise.all([
      this.messageModel
        .deleteMany({ conversationId: { $in: conversationIds } })
        .exec(),
      this.conversationModel
        .deleteMany({ _id: { $in: conversationIds } })
        .exec(),
    ]);
  }

  /**
   * Posts an order event message into the buyer-seller conversation for the product
   * (creating the conversation if it does not exist yet) and updates `activeOrderId`.
   */
  async postOrderEventMessage(params: {
    buyerId: string;
    sellerId: string;
    productId: string;
    orderId: string;
    senderId: string;
    content: string;
  }): Promise<string | null> {
    if (
      !Types.ObjectId.isValid(params.buyerId) ||
      !Types.ObjectId.isValid(params.sellerId) ||
      !Types.ObjectId.isValid(params.productId) ||
      !Types.ObjectId.isValid(params.orderId) ||
      !Types.ObjectId.isValid(params.senderId)
    ) {
      return null;
    }

    const buyerObjId = new Types.ObjectId(params.buyerId);
    const sellerObjId = new Types.ObjectId(params.sellerId);
    const productObjId = new Types.ObjectId(params.productId);
    const orderObjId = new Types.ObjectId(params.orderId);
    const senderObjId = new Types.ObjectId(params.senderId);

    let conversation = await this.conversationModel
      .findOne({
        buyerId: buyerObjId,
        sellerId: sellerObjId,
        productId: productObjId,
      })
      .exec();

    if (!conversation) {
      try {
        conversation = await this.conversationModel.create({
          buyerId: buyerObjId,
          sellerId: sellerObjId,
          productId: productObjId,
          activeOrderId: orderObjId,
          lastMessage: params.content,
          lastMessageAt: new Date(),
        });
      } catch (err) {
        if ((err as { code?: number })?.code === 11000) {
          conversation = await this.conversationModel
            .findOne({
              buyerId: buyerObjId,
              sellerId: sellerObjId,
              productId: productObjId,
            })
            .exec();
        }
      }
    }

    if (!conversation) {
      return null;
    }

    const now = new Date();
    await this.messageModel.create({
      conversationId: conversation._id,
      senderId: senderObjId,
      content: params.content,
      messageType: MessageType.ORDER,
      orderId: orderObjId,
      isRead: false,
    });

    await this.conversationModel
      .updateOne(
        { _id: conversation._id },
        {
          $set: {
            activeOrderId: orderObjId,
            lastMessage: params.content,
            lastMessageAt: now,
          },
        },
      )
      .exec();

    this.realtimeService?.emitToUsers([params.buyerId, params.sellerId], {
      type: 'ORDER_UPDATED',
      conversationId: String(conversation._id),
      orderId: params.orderId,
      productId: params.productId,
    });

    return String(conversation._id);
  }

  private isParticipant(
    conversation: ConversationDocument,
    userId: string,
  ): boolean {
    const buyerIdStr = String(
      (conversation.buyerId as unknown as { _id?: Types.ObjectId })?._id ??
        conversation.buyerId,
    );
    const sellerIdStr = String(
      (conversation.sellerId as unknown as { _id?: Types.ObjectId })?._id ??
        conversation.sellerId,
    );

    return buyerIdStr === String(userId) || sellerIdStr === String(userId);
  }
}
