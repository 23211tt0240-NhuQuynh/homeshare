# Quản lý người thuê và ở ghép

`residents` là nguồn thông tin người đang ở. `host_rooms` giữ phòng và trạng thái, không ghi tên/SĐT/danh sách người thuê. Booking giữ lịch sử người đặt và trạng thái đơn; không thay thế hồ sơ cư dân. Bộ lọc chung cư/phòng dùng ID phòng gốc, không dùng tiêu đề bài đăng.

## Sửa lỗi merge ngày 30/10/2026

Nhánh check-in nhanh bị merge về cách ghi `residents.periodId = bookingId` nhưng không tạo document tương ứng trong `periods`. Đồng thời `residents.roomId` có thể là ID bài đăng. Vì thế duyệt ở ghép không tìm được kỳ ở/người thuê chính.

- Check-in nhanh dùng lại ResidentService.preparePrimary; kỳ ở, cư dân, booking và trạng thái phòng được commit cùng một batch.
- ID document cư dân ngẫu nhiên tự nó không sai. Khi gặp dữ liệu cũ đúng dạng này, bước duyệt ở ghép xác minh booking thuộc người thuê và phòng rồi tạo kỳ ở thật, cập nhật con trỏ trên chính document cư dân cũ. Giữ nguyên ID và ngày vào ở, không xóa người cũ hoặc tạo trùng.
- Phòng gốc được phân giải qua liên kết bài đăng. Đọc được cả cư dân cũ mang ID bài đăng và cư dân mới mang ID phòng.
- Yêu cầu chỉ có trạng thái khách chấp nhận vẫn cần chủ trọ Duyệt vào phòng. Thêm người ở ghép và đánh dấu thông báo đã duyệt cùng batch. Chỉ xử lý đóng tin ở ghép đủ sức chứa sau khi batch đó thành công.
- Không tự khôi phục kỳ ở đã kết thúc hoặc tự sửa hồ sơ nếu UID/phòng của booking không khớp.

Chạy lại ứng dụng từ dev-TOAN rồi duyệt lại yêu cầu ở ghép đang chờ. Nút Đồng bộ hồ sơ nhận phòng cũng sửa được dạng periodId bằng mã booking dù hồ sơ cư dân đã tồn tại. Dữ liệu cũ chỉ được sửa khi thao tác được thực hiện qua bản mã mới; chưa thay đổi trực tiếp Firebase thật trong phiên làm việc này.

Test hồi quy: test/roommate_resident_merge_regression_test.dart, gồm cả stream thật của TenantRepository khi thêm người ở ghép trong lúc danh sách đang mở. Fake Firestore chỉ mô phỏng lưu trữ để kiểm tra mã, không kiểm tra rules đang triển khai trên Firebase.

## Checkout từng cư dân

Danh sách checkout lấy từng người đang ở từ residents, lưu residentId vào biên bản. Chỉ người được chọn được chuyển sang moved_out. Kỳ thuê dùng chung giữ dangO khi còn thành viên; phòng giữ occupied và thông tin hợp đồng khi còn người ở. Người cuối cùng rời đi mới giải phóng phòng. QR phòng có nhiều cư dân yêu cầu chọn người trước khi xác nhận. Cọc phòng chỉ được điền mặc định cho hồ sơ chính; người ở ghép mặc định 0 vì chưa có dữ liệu cọc riêng.

Test hồi quy: test/checkout_resident_test.dart. Không tự sửa hoặc khôi phục dữ liệu đã checkout nhầm trước đó trên Firebase.
