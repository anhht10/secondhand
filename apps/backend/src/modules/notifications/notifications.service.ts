import {
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { PaginationMeta } from '../../common/interfaces/api-response.interface';
import { RealtimeService } from '../realtime/realtime.service';
import {
  Notification,
  NotificationDocument,
  NotificationType,
} from './schemas/notification.schema';

export interface CreateNotificationInput {
  recipientId: string;
  actorId?: string | null;
  type: NotificationType;
  title: string;
  body: string;
  orderId?: string | null;
  productId?: string | null;
}

export interface PaginatedNotificationsResult {
  items: NotificationDocument[];
  unreadCount: number;
  meta: PaginationMeta;
}

@Injectable()
export class NotificationsService {
  constructor(
    @InjectModel(Notification.name)
    private readonly notificationModel: Model<NotificationDocument>,
    @Optional()
    private readonly realtimeService?: RealtimeService,
  ) {}

  async createNotification(
    input: CreateNotificationInput,
  ): Promise<NotificationDocument | null> {
    if (!Types.ObjectId.isValid(input.recipientId)) {
      return null;
    }

    const created = await this.notificationModel.create({
      recipientId: new Types.ObjectId(input.recipientId),
      actorId:
        input.actorId && Types.ObjectId.isValid(input.actorId)
          ? new Types.ObjectId(input.actorId)
          : null,
      type: input.type,
      title: input.title.trim(),
      body: input.body.trim(),
      orderId:
        input.orderId && Types.ObjectId.isValid(input.orderId)
          ? new Types.ObjectId(input.orderId)
          : null,
      productId:
        input.productId && Types.ObjectId.isValid(input.productId)
          ? new Types.ObjectId(input.productId)
          : null,
      isRead: false,
    });

    this.realtimeService?.emitToUsers([input.recipientId, input.actorId], {
      type: 'NOTIFICATION_CREATED',
      orderId: input.orderId ?? undefined,
      productId: input.productId ?? undefined,
    });

    return created;
  }

  async findUserNotifications(
    userId: string,
    page = 1,
    limit = 20,
  ): Promise<PaginatedNotificationsResult> {
    const safePage = Math.max(1, page);
    const safeLimit = Math.min(100, Math.max(1, limit));
    const skip = (safePage - 1) * safeLimit;
    const recipientObjId = new Types.ObjectId(userId);

    const [items, total, unreadCount] = await Promise.all([
      this.notificationModel
        .find({ recipientId: recipientObjId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(safeLimit)
        .exec(),
      this.notificationModel
        .countDocuments({ recipientId: recipientObjId })
        .exec(),
      this.notificationModel
        .countDocuments({ recipientId: recipientObjId, isRead: false })
        .exec(),
    ]);

    const totalPages = Math.ceil(total / safeLimit) || 1;
    return {
      items,
      unreadCount,
      meta: {
        total,
        page: safePage,
        limit: safeLimit,
        totalPages,
        hasNextPage: safePage < totalPages,
        hasPrevPage: safePage > 1,
      },
    };
  }

  async markAsRead(
    notificationId: string,
    userId: string,
  ): Promise<NotificationDocument> {
    if (!Types.ObjectId.isValid(notificationId)) {
      throw new NotFoundException('Notification not found');
    }

    const notification = await this.notificationModel
      .findById(notificationId)
      .exec();
    if (!notification) {
      throw new NotFoundException('Notification not found');
    }

    if (String(notification.recipientId) !== String(userId)) {
      throw new ForbiddenException(
        'You do not have permission to modify this notification',
      );
    }

    if (!notification.isRead) {
      notification.isRead = true;
      await notification.save();
    }

    return notification;
  }

  async markAllAsRead(userId: string): Promise<{ modifiedCount: number }> {
    const res = await this.notificationModel
      .updateMany(
        {
          recipientId: new Types.ObjectId(userId),
          isRead: false,
        },
        { $set: { isRead: true } },
      )
      .exec();

    return { modifiedCount: res.modifiedCount ?? 0 };
  }
}
