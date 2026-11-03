import { Injectable, MessageEvent } from '@nestjs/common';
import { Observable, Subject } from 'rxjs';
import { filter, map } from 'rxjs/operators';

export type RealtimeEventType =
  | 'MESSAGE_CREATED'
  | 'CONVERSATION_UPDATED'
  | 'ORDER_CREATED'
  | 'ORDER_UPDATED'
  | 'PAYMENT_UPDATED'
  | 'REVIEW_UPDATED'
  | 'NOTIFICATION_CREATED';

export interface RealtimeEventPayload {
  id: string;
  type: RealtimeEventType;
  targetUserIds: string[];
  conversationId?: string;
  orderId?: string;
  productId?: string;
  sellerId?: string;
  status?: string;
  paymentStatus?: string;
  timestamp: number;
}

@Injectable()
export class RealtimeService {
  private readonly eventSubject = new Subject<RealtimeEventPayload>();
  private readonly userEventHistory = new Map<string, RealtimeEventPayload[]>();
  private static readonly MAX_EVENTS_PER_USER = 100;
  private sequence = 0;

  /**
   * Emits a real-time event to one or more users (e.g. buyer and seller).
   */
  emitToUsers(
    userIds: Array<string | undefined | null>,
    event: Omit<RealtimeEventPayload, 'id' | 'targetUserIds' | 'timestamp'>,
  ): RealtimeEventPayload {
    const uniqueTargets = Array.from(
      new Set(
        userIds
          .filter((id): id is string => typeof id === 'string' && id.trim().length > 0)
          .map((id) => id.trim()),
      ),
    );

    const now = Date.now();
    this.sequence += 1;
    const payload: RealtimeEventPayload = {
      ...event,
      id: `evt_${now}_${this.sequence}`,
      targetUserIds: uniqueTargets,
      timestamp: now,
    };

    for (const userId of uniqueTargets) {
      const list = this.userEventHistory.get(userId) ?? [];
      list.push(payload);
      if (list.length > RealtimeService.MAX_EVENTS_PER_USER) {
        list.splice(0, list.length - RealtimeService.MAX_EVENTS_PER_USER);
      }
      this.userEventHistory.set(userId, list);
    }

    this.eventSubject.next(payload);
    return payload;
  }

  /**
   * Returns an RxJS Observable suitable for NestJS `@Sse()` streaming for a specific user.
   */
  subscribeForUser(userId: string): Observable<MessageEvent> {
    const normalizedUserId = userId.trim();
    return this.eventSubject.asObservable().pipe(
      filter((evt) => evt.targetUserIds.includes(normalizedUserId)),
      map(
        (evt): MessageEvent => ({
          id: evt.id,
          type: evt.type,
          data: evt,
        }),
      ),
    );
  }

  /**
   * Returns all events for `userId` with `timestamp > since` (in-memory O(1) lookup).
   */
  getEventsSince(
    userId: string,
    sinceTimestamp = 0,
  ): {
    serverTime: number;
    hasChanges: boolean;
    events: RealtimeEventPayload[];
  } {
    const normalizedUserId = userId.trim();
    const list = this.userEventHistory.get(normalizedUserId) ?? [];
    const since = Number.isFinite(sinceTimestamp) ? sinceTimestamp : 0;
    const events =
      since > 0 ? list.filter((e) => e.timestamp > since) : list.slice(-10);

    return {
      serverTime: Date.now(),
      hasChanges: events.length > 0,
      events,
    };
  }
}
