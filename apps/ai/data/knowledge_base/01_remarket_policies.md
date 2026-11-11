---
document_id: remarket-policies
title: Chính sách và Quy định Hoạt động của ReMarket
category: policy
created_at: 2026-11-06T00:00:00Z
---

# Chính sách và Quy định Hoạt động của ReMarket

## 1. Nguyên tắc Minh bạch Bắt buộc (Defect Disclosure)
ReMarket là sàn giao dịch đồ cũ dành cho sinh viên với tiêu chuẩn minh bạch cao. Người bán bắt buộc phải:
- Khai báo trung thực mọi lỗi ngoại hình và chức năng trong mục `defectDisclosure` (ví dụ: trầy xước vỏ, chai pin, liệt phím, rách bìa sách).
- Đăng tải hình ảnh thật của sản phẩm đang bán (tối đa 10 ảnh mỗi tin đăng, dung lượng tối đa 5MB/ảnh, định dạng JPEG, PNG hoặc WEBP).
- Không sử dụng ảnh mạng hoặc ảnh đã qua chỉnh sửa che giấu khuyết điểm.

## 2. Danh mục Hàng hóa Bị Cấm
Nghiêm cấm đăng bán các mặt hàng sau trên ReMarket:
- Hàng giả, hàng nhái thương hiệu không được khai báo rõ nguồn gốc.
- Vũ khí, chất cấm, thuốc lá điện tử, đồ uống có cồn.
- Tài khoản số lậu, phần mềm bẻ khóa, giấy tờ tùy thân hoặc thẻ sinh viên giả.
- Thiết bị điện tử bị khóa iCloud, khóa mật khẩu BIOS/MDM hoặc có nguồn gốc bất hợp pháp.

## 3. Quy định về Trạng thái Tin đăng (Product Status)
Mỗi sản phẩm trên ReMarket tuân theo vòng đời trạng thái:
- `DRAFT`: Bản nháp, chỉ người bán nhìn thấy.
- `ACTIVE`: Đang hiển thị công khai trên sàn.
- `RESERVED`: Đã có người mua hẹn giữ chỗ.
- `SOLD`: Đã giao dịch thành công (không thể xóa hoặc sửa thông tin mô tả/giá sau khi đã chuyển sang `SOLD`, chỉ được phép chuyển sang `ARCHIVED`).
- `ARCHIVED`: Tin đã lưu trữ, ẩn khỏi tìm kiếm công khai.

## 4. Báo cáo Vi phạm (Report Policy)
Người mua có quyền gửi báo cáo (`POST /api/v1/reports`) kèm tối đa 5 URL bằng chứng nếu phát hiện tin đăng lừa đảo, sai sự thật hoặc bán hàng cấm. Hệ thống chặn việc tự báo cáo sản phẩm của chính mình và chống spam báo cáo trùng lặp.
