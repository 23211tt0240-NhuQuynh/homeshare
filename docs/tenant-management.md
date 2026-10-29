# Quản lý người thuê sau check-in

Chỉ nhận khách đã xác nhận check-in bằng luồng QR hiện có. Đơn mới duyệt hoặc thanh toán chưa được tính. Đã bỏ nút và API thêm khách thủ công; không thay đổi luồng đặt phòng, thanh toán, QR, bàn giao hoặc check-out.

Đọc trạng thái active/dangO/daNhanPhong và cờ isCheckIn/daNhanPhong của booking thuộc chủ trọ; loại đơn đã hủy/trả phòng và source host_manual. Ưu tiên kỳ ở/cư dân khi có; nếu thiếu bản ghi host_rooms hoặc kỳ ở thì vẫn hiển thị người thuê từ booking. Chỉ số người thuê tính thành viên đang ở, hỗ trợ tìm kiếm, lọc cơ sở và xem hồ sơ.

Kiểm tra thực tế: duyệt đơn chưa hiển thị; xác nhận QR hiển thị khách; cả hai nhánh check-in hoạt động; kiểm tra đơn không có host_rooms tương ứng; kiểm tra ở ghép, đổi tài khoản, nhắn tin trong ứng dụng và kết nối. Chưa đối chiếu dữ liệu khách thật trên Firebase. Quyền dữ liệu phụ thuộc rules đang triển khai.

Nút SMS trên thẻ người thuê mở ChatDetailScreen có sẵn theo UID người thuê từ booking/kỳ ở. Không gọi điện hoặc mở ứng dụng SMS điện thoại. Không tự gửi tin nhắn khi mở cuộc trò chuyện.

Bộ lọc cơ sở/phòng phân giải booking.roomId qua posts.roomId (hoặc khóa ngoại tương đương) về host_rooms.id, sau đó lấy propertyId của phòng. Tiêu đề bài đăng không dùng làm tên phòng khi có phòng gốc. Dữ liệu cũ thiếu liên kết vẫn có hồ sơ booking nhưng không suy đoán cơ sở theo tên.

Ở ghép: chấp nhận lời mời chỉ gửi yêu cầu duyệt. Sau khi chủ trọ duyệt, residents mới được tạo. Kỳ ở do duyệt ở ghép có thể thiếu bookingId; danh sách nối bằng UID người thuê chính và phòng gốc với đơn đã check-in, không nối bằng tên hoặc với đơn chưa nhận phòng.
