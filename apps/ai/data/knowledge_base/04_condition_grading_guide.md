---
document_id: condition-grading-guide
title: Tiêu chuẩn Phân loại Tình trạng Sản phẩm trên ReMarket
category: condition_grading
created_at: 2026-11-06T00:00:00Z
---

# Tiêu chuẩn Phân loại Tình trạng Sản phẩm trên ReMarket

ReMarket áp dụng 4 cấp độ tình trạng sản phẩm chuẩn hóa (`ProductCondition`) để người mua và người bán định giá công bằng:

## 1. `NEW` (Mới 100%)
- Sản phẩm chưa qua sử dụng, còn nguyên hộp/tem niêm phong hoặc chỉ vừa mở hộp kiểm tra.
- Không có bất kỳ vết trầy xước hay hao mòn nào; đầy đủ 100% phụ kiện gốc của nhà sản xuất.
- Mức giá tham khảo thông thường: đạt khoảng 80% - 90% giá mua mới (`originalPrice`).

## 2. `LIKE_NEW` (Như mới — 95% đến 99%)
- Sản phẩm đã qua sử dụng thời gian ngắn, giữ gìn rất kỹ, ngoại hình gần như mới.
- Có thể có vết xước dăm cực nhỏ ở vỏ hộp hoặc đế máy nhưng hoàn toàn không ảnh hưởng thẩm mỹ; mọi chức năng hoạt động hoàn hảo 100%.
- Mức giá tham khảo thông thường: đạt khoảng 65% - 80% giá mua mới.

## 3. `GOOD` (Tốt — 85% đến 94%)
- Sản phẩm đã sử dụng thường xuyên, có dấu hiệu hao mòn tự nhiên rõ ràng (xước nhẹ ở vỏ, mòn nhẹ đệm tai hoặc bìa sách có nếp gấp).
- Tất cả các chức năng chính vẫn hoạt động ổn định, không có lỗi nghiêm trọng.
- Mức giá tham khảo thông thường: đạt khoảng 45% - 65% giá mua mới.

## 4. `FAIR` (Khá / Cũ — Dưới 85%)
- Sản phẩm có khuyết điểm ngoại hình rõ rệt (cấn móp góc, trầy nhiều, chai pin hoặc thiếu phụ kiện đi kèm) hoặc một số tính năng phụ hoạt động hạn chế nhưng vẫn dùng được cho nhu cầu cơ bản.
- Bắt buộc khai báo chi tiết từng khuyết điểm trong `defectDisclosure`.
- Mức giá tham khảo thông thường: đạt khoảng 25% - 45% giá mua mới.
