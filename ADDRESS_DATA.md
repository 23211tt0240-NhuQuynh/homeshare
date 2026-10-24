# Dữ liệu địa chỉ

Ứng dụng dùng danh mục hành chính hai cấp: tỉnh/thành → phường/xã/đặc khu.
Nguồn: https://provinces.open-api.vn/ (API v2).
Bản dự phòng tải ngày 23/10/2026 gồm 34 tỉnh/thành và 3.321 đơn vị cấp xã.

Khi khởi động, `VietnamLocations.initialize()` đọc cache rồi tải lại API v2
(timeout 6 giây). Chỉ thay danh mục khi toàn bộ phản hồi hợp lệ. Khi mất mạng
hoặc API lỗi, dùng cache hoặc bản dự phòng. Mức độ cập nhật phụ thuộc nguồn API;
không thể bảo đảm dữ liệu mới hơn nguồn cung cấp.

Chạy `python scripts/refresh_vietnam_addresses.py` để cập nhật bản dự phòng
trước khi phát hành. Kiểm tra thay đổi danh mục và chạy kiểm thử địa chỉ sau đó.

Các trường `district` cũ được giữ để đọc bản ghi lịch sử. Cơ sở mới không ghi trường district; khi lưu chỉnh sửa cơ sở, các trường district,
quan_huyen và quanHuyen cũ được xóa bằng FieldValue.delete(). Cơ sở lưu ward hiện hành; bài tìm ở ghép lưu địa chỉ hai cấp. RoomModel vẫn dùng
trường district để chứa địa bàn tìm kiếm theo schema hiện có.
Không tự chuyển tên phường cũ sang phường mới vì có thể phải xác định theo số nhà
hoặc ranh giới chia tách. Khi chỉnh sửa địa chỉ cũ, người dùng phải chọn lại danh
mục hiện hành; nội dung chưa nhận diện trong địa chỉ gốc được giữ lại để đối chiếu.

Không có thao tác cập nhật hàng loạt Firestore hoặc triển khai bản app trong thay đổi này.
