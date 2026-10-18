# Quản lý phòng chủ trọ

Luồng: Quản lý nhà → Quản lý phòng → Chi tiết → Chỉnh sửa.

- Mỗi thẻ cơ sở có menu ba chấm để sửa hoặc xóa. Form sửa dùng lại form tạo cơ sở, giữ ảnh hiện có và không làm đổi ID/liên kết phòng. Chỉ xóa mềm cơ sở không còn phòng.
- Danh sách và chi tiết đọc stream `properties`/`host_rooms` của UID đang đăng nhập. Collection `rooms` công khai của khách thuê không bị ghi bởi module này.
- Form sửa cập nhật mã phòng, tầng, diện tích, sức chứa, giá/cọc, phí, tiện ích, mô tả và ảnh. ID phòng không đổi; trạng thái, khách thuê và hợp đồng không bị form ghi đè.
- Các phí mới: `electricityRate`, `waterRate`, `serviceFee`. Phòng cũ thiếu phí hiển thị “Chưa thiết lập”.
- Thông tin khách thuê dùng các trường `tenantName`, `tenantPhone`, `contractId`, `contractStart`, `contractEnd`; chưa có dữ liệu thì hiển thị trống. Luồng gán khách/hợp đồng cần được module hợp đồng của nhóm cập nhật, không tự suy ra từ đơn đặt phòng.
- `properties.roomCodes` giữ mã phòng duy nhất. Tài liệu phòng trong `host_rooms` dùng ID có mã thao tác.
- Lưu kiểm tra `updatedAt` để tránh ghi đè bản sửa từ thiết bị khác.
- Xóa sau xác nhận đánh dấu `status: deleted`, giảm `roomCount`, bỏ mã phòng khỏi `roomCodes`. Bản ghi và ảnh cũ giữ lại cho lịch sử. Không cho xóa phòng đang thuê, giữ chỗ hoặc còn khách/hợp đồng.

Các file Rules trong repository đã được tách quyền cho `host_rooms`, nhưng vẫn là bản nháp/snippet và chưa tự động publish lên Firebase. Phải đối chiếu với Rules đang chạy trước khi ghép và triển khai.

Kiểm thử giao diện dùng repository giả, không chứng minh quyền truy cập trên Firebase thật. Việc tải ảnh và ghi dữ liệu thật phụ thuộc tài khoản đăng nhập và Rules Firestore/Storage của dự án.

## ID và tên phòng

- Phòng mới chỉ có một khóa định danh: document ID bằng trường `id`, gồm 12 ký tự ngẫu nhiên, không ghép tên cơ sở, tầng hoặc mã thao tác. Booking, bài đăng, ảnh, tiện ích và kỳ ở dùng cùng giá trị này trong `roomId`.
- `title` là tên chủ trọ nhập, bắt buộc 1–100 ký tự. Chủ trọ có thể đặt tên `NTLVM03-02` hoặc tên mô tả tùy ý.
- Giao diện ghi “Mã phòng”, chỉ đọc và hiển thị chính `id`. ID giữ nguyên khi đổi tầng, tên hoặc sửa thông tin khác; không còn chữ “tự sinh” trên nhãn.
- Luồng tạo mới không lưu `roomCode` hoặc `operationId` trong document phòng, không cấp số theo tầng. Form giữ nguyên ID khi thử lưu lại; transaction kiểm tra document và tăng roomCount một lần.
- Model vẫn đọc roomCode cũ để tương thích với dữ liệu và các màn hình cũ, nhưng mapper mới không ghi trường này. Các phòng cũ giữ nguyên document ID; không tự di trú, đổi ID hoặc xóa hàng loạt trường trên Firebase.
- Rules nháp/snippet kiểm tra `id` trùng document ID và tên có dữ liệu. Các điều kiện quyền sở hữu giữ nguyên; kiểm tra operationId cũ vẫn yêu cầu không thay đổi nếu document cũ có trường đó. Chưa triển khai rules lên Firebase.

## Tiền cọc theo tỷ lệ

- Form tạo và sửa phòng dùng ô chọn 10%, 20%, …, 100%. Không nhập trực tiếp số tiền cọc. Phòng mới mặc định 20%.
- Tiền cọc tự cập nhật theo giá thuê tháng và tỷ lệ đã chọn, làm tròn tới đồng. Lưu `depositPercentage` là số nguyên và `deposit` là số tiền tương ứng; repository kiểm tra hai giá trị trước khi ghi.
- Phòng cũ có cọc khớp một mức hợp lệ sẽ tự chọn mức đó. Nếu cọc 0 hoặc không khớp, form giữ số tiền cũ để đối chiếu và yêu cầu chọn tỷ lệ trước khi lưu; không tự đổi dữ liệu cũ hàng loạt.
- Luồng đăng bài từ phòng hỗ trợ cả mức 60–100%, không ép tỷ lệ về tối đa 50%.
