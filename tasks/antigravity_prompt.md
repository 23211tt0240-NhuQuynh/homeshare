# Prompt gửi Antigravity

Tiếp tục triển khai trên workspace `D:/App/AI/homeshare-dev-THE-on-dev`.

Đọc trước:

- `tasks/plan.md`, mục “Active Plan — Bộ lọc Check-in/Check-out, cọc 10–20% và bỏ isAvailable khi checkout”.
- `tasks/todo.md`, mục active tương ứng.
- `tiendo.md` để hiểu tiến độ dự án.
- `git diff` để bảo toàn các thay đổi đang làm dở.

Yêu cầu bắt buộc:

1. Hoàn thiện bộ lọc theo tầng và phòng tại `HostCheckinCheckoutScreen`:
   - Dùng dữ liệu thật từ hai provider check-in/check-out.
   - Có “Tất cả tầng” và “Tất cả phòng”.
   - Phòng được lọc theo tầng; đổi tầng phải bỏ lựa chọn phòng không còn hợp lệ.
   - Dùng `roomId` làm khóa lọc, `roomCode` chỉ hiển thị.
   - Áp dụng cho cả danh sách check-in và check-out, có trạng thái không tìm thấy kết quả và không overflow ở 320px.

2. Tiền cọc khi Chủ trọ tạo/sửa phòng chỉ có 10%, 15%, 20%:
   - Dùng duy nhất `roomDepositPercentages`.
   - Sửa `roomDeposit` để từ chối mọi tỷ lệ không thuộc danh sách, kể cả 5%, 9%, 21%, 25%.
   - Đồng bộ tạo phòng, sửa phòng, tạo bài đăng và provider/service validation.

3. Checkout không được sinh trường `isAvailable`:
   - Bỏ các write `isAvailable: true/false` trong `CheckinCheckoutRepository.checkout`.
   - Khi checkout người cuối, `status: available`; khi còn người, `status: occupied`.
   - Xóa field legacy `isAvailable` khỏi document phòng nếu đang tồn tại.
   - Ngăn call gián tiếp tới `restorePostOnCancelledBooking` ghi lại `isAvailable: true`; tách helper hoặc thêm tham số rõ nghĩa để checkout chỉ khôi phục bài đăng.
   - Không thay đổi hành vi hủy booking ngoài checkout.

Quy trình:

- TDD: viết test RED trước từng thay đổi, sau đó GREEN và refactor.
- Không hardcode dữ liệu tầng/phòng.
- Không ghi đè hoặc hoàn tác thay đổi hiện có của người khác.
- Không dùng lệnh phá hủy Git.
- Không commit và tuyệt đối không push.
- Sau mỗi lát cắt, chạy focused tests và analyzer.
- Cuối cùng cập nhật `tiendo.md` bằng kết quả thật, rồi dừng để Codex review diff.
