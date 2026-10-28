# Quản lý người thuê: residents là nguồn dữ liệu người ở

Người đang ở chỉ lưu tại collection `residents`: userId, fullName, phone, avatar, roomId, periodId, formId, statusId, moveInDate, moveOutDate. `host_rooms` giữ phòng, propertyId, trạng thái và liên kết hợp đồng; không ghi tenantName, tenantPhone, tenantAvatar, tenantIds hoặc roommates.

- Check-in QR nhanh tạo/cập nhật kỳ ở và cư dân chính cùng batch với booking/phòng.
- Bàn giao đầy đủ dùng lại kỳ ở/cư dân, thêm phiếu check-in và chỉ số điện nước.
- Khách chấp nhận lời mời ở ghép vẫn cần chủ trọ duyệt. Khi duyệt, thêm bản ghi residents, không sao chép người ở vào phòng.
- Danh sách người thuê đọc residents; đơn đã duyệt hoặc booking đang ở mà chưa có residents không tự biến thành người ở.
- Các trường tên/SĐT trên RoomModel chỉ là dữ liệu ghép trong bộ nhớ từ residents để giữ giao diện phòng/trả phòng hiện tại. RoomModel không đọc lại bản sao tên/SĐT trong host_rooms.
- Trả phòng cập nhật trạng thái rời đi trong residents. Danh sách chỉ tính người còn đang ở, gộp trùng UID trong cùng phòng.
- Booking vẫn giữ thông tin người đặt tại thời điểm đặt; đó là lịch sử giao dịch, không phải bảng người đang ở.

## Dữ liệu cũ trên Firebase

Sửa mã không tự xóa các field đã có trên Firebase. Cần chuyển dữ liệu cũ trước khi kiểm thử dữ liệu thật nếu có khách chỉ tồn tại trong host_rooms/bookings.

Đã có script `functions/scripts/migrate-residents.cjs`. Chạy trong thư mục functions sau khi cài các dependency hiện có và cấu hình Application Default Credentials có quyền Firestore:

```powershell
node scripts/migrate-residents.cjs --project homeshare-fe18e
```

Mặc định chỉ đọc và in kế hoạch, không ghi dữ liệu. Sau khi kiểm tra danh sách, chạy:

```powershell
node scripts/migrate-residents.cjs --project homeshare-fe18e --apply --backup residents-before-migration.json
```

Script lưu snapshot JSON mới (không ghi đè file có sẵn) trước khi thực hiện. JSON dùng để kiểm tra dữ liệu trước chuyển đổi, không phải định dạng managed Firestore export. Dữ liệu từng phòng được cập nhật trong một batch: tạo/bổ sung cư dân và kỳ ở rồi mới xóa field sao chép khỏi host_rooms. Có precondition phiên bản tài liệu; nếu dữ liệu đổi trong lúc chạy thì batch thất bại để tránh ghi đè thay đổi mới. Có thể chạy lại dry-run và apply với tên backup mới. Phòng không xác định được UID/chủ sở hữu/phòng gốc hoặc thành viên chưa đủ dữ liệu sẽ bị bỏ qua; không suy đoán UID theo tên. Không xóa document phòng, booking, residents hay lịch sử giao dịch.

Chưa chạy migration trên Firebase thật từ phiên làm việc này. Cần kiểm tra quyền đọc/ghi của Firestore rules đang triển khai.

## Kết quả kiểm tra

- 37 test thuộc nhóm cư dân, quản lý chủ trọ, đặt phòng, QR và chuẩn hóa trạng thái đã pass.
- 4 test kế hoạch chuyển dữ liệu cũ đã pass; script qua kiểm tra cú pháp Node.
- Analyzer không có lỗi/cảnh báo trên các file triển khai và test ghi cư dân.
- Chạy toàn bộ suite còn có lỗi ở kiểm thử chat, layout dashboard và các ánh xạ dữ liệu/khóa DrawIO khác. Chưa kết luận toàn bộ dự án pass. Không thay đổi chức năng tương ứng để xử lý các lỗi ngoài phạm vi này.

## Khôi phục đơn đã nhận phòng nhưng thiếu residents

Sau khi chạy lại ứng dụng bằng mã mới, vào Quản lý người thuê → Đồng bộ hồ sơ nhận phòng. Chức năng này dùng phiên chủ trọ hiện tại, chỉ bổ sung hồ sơ cho đơn có trạng thái đang ở và thời điểm xác nhận nhận phòng. Đọc lại booking/phòng trong transaction, không tạo trùng, không sửa ngày nhận phòng trên booking hoặc gửi lại thông báo; không ghi người vào host_rooms. Bỏ qua đơn đã kết thúc kỳ ở, phòng đã có người thuê chính khác, hoặc dữ liệu không chứng minh được việc nhận phòng. Thông báo kết quả ghi rõ số hồ sơ đã bổ sung và số đơn cần kiểm tra. Đây là chức năng trong app, không cần script tạm hay quyền Admin CLI.

## Duyệt ở ghép

Khách đồng ý lời mời chỉ tạo yêu cầu chờ chủ trọ. Trạng thái trong chat ghi rõ chờ chủ trọ duyệt. Khi chủ trọ duyệt, residents của người mới và thông báo duyệt được commit trong cùng một batch. Kỳ ở được chọn từ residents đang hoạt động của người thuê chính, không lấy một kỳ ở bất kỳ trong phòng. Thiếu hồ sơ cư dân chính/kỳ ở thì báo lỗi cụ thể, không báo thành công. Lời mời mới chọn phòng từ residents hiện tại của người gửi, không chọn từ đơn cọc hoặc booking cũ.
