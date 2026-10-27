# ReMarket — Payment & Bank Transfer Security Workflow (`PAYMENT_WORKFLOW.md`)

## 1. Overview

ReMarket supports three practical payment methods tailored for student & community second-hand trading:
1. **`CASH` (Tiền mặt khi gặp mặt)**: Valid with `MEETUP`. Paid directly upon in-person inspection; automatically marked `PAID` when the order reaches `COMPLETED`.
2. **`COD` (Thanh toán khi nhận hàng)**: Valid with `DELIVERY`. Paid upon delivery inspection; automatically marked `PAID` when the order reaches `COMPLETED`.
3. **`BANK_TRANSFER` (Chuyển khoản ngân hàng trực tiếp)**: Valid with both `MEETUP` and `DELIVERY`. Uses a two-step verification workflow (**Buyer Confirmation $\rightarrow$ Seller Confirmation**) backed by a dedicated `Payment` collection (`payments`).

---

## 2. Two-Step Bank Transfer Verification State Machine

```mermaid
sequenceDiagram
    participant Buyer
    participant Backend as NestJS OrdersService
    participant DB as MongoDB (orders + payments)
    participant Seller

    Buyer->>Backend: POST /api/v1/orders (paymentMethod = BANK_TRANSFER)
    Backend->>DB: Create Order (status=PENDING, paymentStatus=UNPAID) + Payment (status=UNPAID)
    Backend-->>Buyer: 201 Created (includes sellerBankInfo + transferContent = orderCode)

    Buyer->>Backend: POST /api/v1/orders/:id/payment-confirmation (transactionReference, transferNote)
    Note over Backend,DB: Buyer-only guard; requires paymentStatus == UNPAID
    Backend->>DB: Update Order & Payment -> status = BUYER_CONFIRMED (buyerConfirmationAt = now)
    Backend-->>Seller: Notification (PAYMENT_BUYER_CONFIRMED) + Chat ORDER message

    Seller->>Backend: PATCH /api/v1/orders/:id/payment/confirm (note)
    Note over Backend,DB: Seller-only guard; requires paymentStatus == BUYER_CONFIRMED
    Backend->>DB: Update Order & Payment -> status = PAID (sellerConfirmationAt = now, paidAt = now)
    Backend-->>Buyer: Notification (PAYMENT_CONFIRMED_BY_SELLER) + Chat ORDER message
```

### Critical Business Rules
- **Buyer Confirmation Does Not Mean Paid**: When the buyer clicks **"Tôi đã chuyển khoản"** (`POST /api/v1/orders/:id/payment-confirmation`), the payment status transitions from `UNPAID` to `BUYER_CONFIRMED` (never directly to `PAID`).
- **Seller Must Verify Receipt**: Only the authenticated seller of the order can call `PATCH /api/v1/orders/:id/payment/confirm`, and only after `paymentStatus === BUYER_CONFIRMED`.
- **Bank Transfer Completion Gate**: For `BANK_TRANSFER` orders, shipping (`SHIPPING`/`DELIVERED`) and final order completion (`COMPLETED`) require `paymentStatus === PAID`.

---

## 3. Payment Record Schema (`payments` Collection)

Stored fields in `D:\cross-ck\apps\backend\src\modules\orders\schemas\payment.schema.ts`:
- `paymentId` / `_id` (`ObjectId`)
- `orderId` (`ObjectId`, unique index)
- `payerId` (`ObjectId`, buyer)
- `receiverId` (`ObjectId`, seller)
- `method` (`CASH` | `COD` | `BANK_TRANSFER`)
- `amount` (`Number`, VND)
- `status` (`UNPAID` | `BUYER_CONFIRMED` | `PAID` | `CANCELLED`)
- `transactionReference` (`String`, optional bank transaction reference code)
- `transferNote` (`String`, optional note)
- `buyerConfirmationAt` (`Date`, nullable)
- `sellerConfirmationAt` (`Date`, nullable)
- `paidAt` (`Date`, nullable)
- `createdAt`, `updatedAt` (`Date`)

---

## 4. Bank Credential Security & Privacy Policy

1. **Strictly Prohibited Fields**:
   - The backend and frontend **never** collect, accept, log, or store `bankPassword`, `OTP`, `CVV`, or full payment card credentials.
2. **Seller Bank Account Privacy**:
   - Sellers configure their receiving bank account (`bankName`, `accountNumber`, `accountHolder`, `branch`) via `PATCH /api/v1/users/me`.
   - Public seller profile endpoints (`GET /api/v1/users/:id`) and product detail endpoints (`GET /api/v1/products/:id`) **never** expose `bankInfo`.
   - `sellerBankInfo` (along with the auto-generated `transferContent: order.orderCode`) is attached **only** in `OrdersService.toOrderDetailResponse()` when:
     1. The requester is the authenticated `buyerId` or `sellerId` of that specific order, AND
     2. The order is active (not `CANCELLED` and not `REJECTED`).
