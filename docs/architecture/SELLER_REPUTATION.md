# ReMarket — Seller Reputation & Trust Score Architecture (`SELLER_REPUTATION.md`)

Tài liệu đặc tả hệ thống tính toán **Điểm uy tín người bán (Seller Reputation Score)**, **Điểm đánh giá trung bình (Rating Summary)** và **Thống kê giao dịch (Transaction Statistics)** trong dự án **ReMarket** (`Phase 9.6`).

---

## 1. Phân tách 3 nhóm chỉ số cốt lõi

Hệ thống tách bạch rõ ràng 3 nhóm dữ liệu trong `ReviewsService.calculateSellerReputation`:

1. **`ratingSummary` (Tổng hợp đánh giá sao)**:
   - `averageRating`: Trung bình cộng số sao (`1..5`) của các đánh giá có `status = VISIBLE`, làm tròn 2 chữ số thập phân.
   - `totalReviews`: Tổng số đánh giá hợp lệ (`VISIBLE`).
   - `star5Count`, `star4Count`, `star3Count`, `star2Count`, `star1Count` & `ratingDistribution`: Phân phối chi tiết từng mức sao.
2. **`transactionStats` (Thống kê giao dịch thực tế)**:
   - `completedOrdersCount`: Số đơn bán đã hoàn tất (`OrderStatus.COMPLETED`).
   - `buyerCancelledOrdersCount`: Số đơn bị người mua chủ động hủy (`OrderStatus.CANCELLED`).
   - `sellerRejectedOrdersCount`: Số đơn bị người bán từ chối (`OrderStatus.REJECTED`).
   - `pendingOrdersCount`: Số đơn đang xử lý (`PENDING`, `CONFIRMED`, `SHIPPING`, `DELIVERED`).
   - `successfulTransactionRate`:
     $$\text{SuccessfulTransactionRate} = \frac{\text{completedOrdersCount}}{\text{completedOrdersCount} + \text{sellerRejectedOrdersCount}} \times 100\%$$
   - `sellerReplyRate`: Tỷ lệ phần trăm đánh giá đã được người bán phản hồi.
3. **`reputationScore` (Điểm uy tín tổng hợp `0..100`)**:
   - Phản ánh đồng thời chất lượng đánh giá, độ tin cậy theo quy mô mẫu (Bayesian confidence) và lịch sử hoàn tất đơn hàng.

---

## 2. Công thức tính `reputationScore` (`0..100`)

Điểm uy tín tổng hợp gồm 3 thành phần minh bạch:

$$\text{ReputationScore} = \text{round}\Big(\text{ clamp}_{0..100}\big(P_{\text{rating}} + P_{\text{volume}} + P_{\text{reliability}}\big)\Big)$$

### 2.1. Thành phần 1 — Chất lượng đánh giá có trọng số tin cậy Bayesian ($P_{\text{rating}}$, tối đa `70` điểm)
Để tránh việc một người bán chỉ có `1` đánh giá `5.0 ★` lại có điểm chất lượng cao hơn người bán có `30` đánh giá trung bình `4.8 ★`, hệ thống sử dụng trung bình Bayesian với hằng số tin cậy $C = 5$ và kỳ vọng nền $m = 4.0$:

$$R_{\text{bayes}} = \frac{C \cdot m + \sum_{i=1}^{N} r_i}{C + N} = \frac{5 \times 4.0 + N \times \text{averageRating}}{5 + N}$$

$$P_{\text{rating}} = \left(\frac{R_{\text{bayes}}}{5.0}\right) \times 70$$

- **Hệ quả**:
  - Người bán mới ($N = 0$): $R_{\text{bayes}} = 4.0 \implies P_{\text{rating}} = 56.0$ điểm.
  - Người bán có $1$ đánh giá $5\star$ ($N = 1$): $R_{\text{bayes}} = \frac{25}{6} \approx 4.17 \implies P_{\text{rating}} \approx 58.33$ điểm.
  - Người bán có $20$ đánh giá trung bình $4.8\star$ ($N = 20$): $R_{\text{bayes}} = \frac{20 + 96}{25} = 4.64 \implies P_{\text{rating}} = 64.96$ điểm.

### 2.2. Thành phần 2 — Kinh nghiệm giao dịch hoàn tất ($P_{\text{volume}}$, tối đa `20` điểm)
Mỗi đơn hàng hoàn tất (`OrderStatus.COMPLETED`) cộng `2.5` điểm kinh nghiệm, tối đa `20` điểm (đạt trần ở `8` đơn hàng hoàn tất):

$$P_{\text{volume}} = \min\big(20,\; \text{completedOrdersCount} \times 2.5\big)$$

### 2.3. Thành phần 3 — Độ tin cậy thực hiện đơn hàng của Seller ($P_{\text{reliability}}$, tối đa `10` điểm)
Tính theo tỷ lệ hoàn tất trên các đơn do người bán quyết định (`completedOrdersCount` so với `sellerRejectedOrdersCount`):

$$P_{\text{reliability}} = \left(\frac{\text{completedOrdersCount}}{\text{completedOrdersCount} + \text{sellerRejectedOrdersCount}}\right) \times 10$$

> [!IMPORTANT]
> **Bảo vệ người bán trước hành vi hủy đơn của người mua**: Các đơn hàng do **Buyer tự hủy** (`OrderStatus.CANCELLED`) được thống kê riêng tại `buyerCancelledOrdersCount` và **tuyệt đối không làm giảm** `successfulTransactionRate` hay `reputationScore` của người bán.

---

## 3. Phân hạng uy tín (`reputationTier`) & Caching (`User.reputationCache`)

| Hạng (`reputationTier`) | Nhãn hiển thị | Điều kiện |
| :--- | :--- | :--- |
| `TRUSTED_SELLER` | Người bán Uy tín cao | `reputationScore >= 85` và `completedOrdersCount >= 3` |
| `RELIABLE_SELLER` | Người bán Đáng tin cậy | `reputationScore >= 70` và `completedOrdersCount >= 1` |
| `NEW_SELLER` | Người bán mới | Chưa có giao dịch hoàn tất và chưa có đánh giá |
| `NEEDS_IMPROVEMENT` | Cần cải thiện | `reputationScore < 60` |

### Cơ chế Cache $O(1)$ trên `User.reputationCache`
- Mỗi khi phát sinh sự kiện:
  1. Tạo đánh giá mới (`POST /api/v1/reviews`)
  2. Chỉnh sửa đánh giá trong 7 ngày (`PATCH /api/v1/reviews/:id`)
  3. Kiểm duyệt ẩn/xóa đánh giá (`VISIBLE` $\leftrightarrow$ `HIDDEN`/`DELETED`)
- `ReviewsService.recalculateSellerReputation(sellerId)` tự động cập nhật trường nhúng `User.reputationCache` (`averageRating`, `totalReviews`, `reputationScore`, `completedOrdersCount`, `updatedAt`).
- Nhờ đó, `GET /api/v1/products/:id` và `GET /api/v1/users/:id` đọc trực tiếp từ `reputationCache` với độ phức tạp $O(1)$ mà không cần thực hiện truy vấn tổng hợp (aggregation) trên toàn bộ bảng `reviews` ở mỗi lần hiển thị thẻ sản phẩm.
