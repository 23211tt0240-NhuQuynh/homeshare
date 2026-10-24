# Quản lý người thuê sau check-in

Chỉ nhận khách đã xác nhận check-in bằng luồng QR hiện có. Đơn mới duyệt hoặc thanh toán chưa được tính. Đã bỏ nút và API thêm khách thủ công; không thay đổi luồng đặt phòng, thanh toán, QR, bàn giao hoặc check-out.

Đọc trạng thái active/dangO/daNhanPhong và cờ isCheckIn/daNhanPhong của booking thuộc chủ trọ; loại đơn đã hủy/trả phòng và source host_manual. Ưu tiên kỳ ở/cư dân khi có; nếu thiếu bản ghi host_rooms hoặc kỳ ở thì vẫn hiển thị người thuê từ booking. Chỉ số người thuê tính thành viên đang ở, hỗ trợ tìm kiếm, lọc cơ sở và xem hồ sơ.

Kiểm tra thực tế: duyệt đơn chưa hiển thị; xác nhận QR hiển thị khách; cả hai nhánh check-in hoạt động; kiểm tra đơn không có host_rooms tương ứng; kiểm tra ở ghép, đổi tài khoản, gọi/SMS và kết nối. Chưa đối chiếu dữ liệu khách thật trên Firebase. Quyền dữ liệu phụ thuộc rules đang triển khai.
