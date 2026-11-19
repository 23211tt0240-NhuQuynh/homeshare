# Kế hoạch điều khiển Antigravity bằng Computer Use

## Mục tiêu

Giao cho Antigravity tiếp tục code trên `D:/App/AI/homeshare-dev-THE-on-dev` theo kế hoạch tại `tasks/plan.md`, gồm:

1. Thêm lọc theo tầng và phòng tại màn hình quản lý Check-in/Check-out.
2. Giới hạn tỷ lệ cọc khi Chủ trọ tạo/sửa phòng ở các mức 10%, 15%, 20%.
3. Luồng checkout không sinh trường legacy `isAvailable`; dùng `status` làm nguồn trạng thái.

Không commit, không push và không xóa các thay đổi đang có.

## Ranh giới an toàn

- Chỉ điều khiển đúng cửa sổ Antigravity được trả về bởi Computer Use; không dùng tọa độ hoặc handle đoán mò.
- Không điều khiển Windows Terminal, PowerShell, Command Prompt hoặc hộp thoại Run bằng Computer Use.
- Dùng shell trực tiếp của Codex để đọc `git diff`, chạy test/analyzer; Computer Use chỉ dùng để trao đổi với Antigravity.
- Không gửi mật khẩu, token, file cấu hình bí mật hoặc dữ liệu người dùng vào Anti.
- Trước thao tác bấm **Send** gửi prompt cho Antigravity, dừng và xin xác nhận người dùng tại đúng thời điểm hành động.
- Nếu xuất hiện hộp thoại quyền hệ thống, đăng nhập hoặc bảo mật, dừng và chuyển lại cho người dùng.
- Không cho Anti commit/push. Nếu Anti tự đề xuất, từ chối và chỉ giữ thay đổi trong working tree.

## Giai đoạn 1 — Chuẩn bị và chọn đúng cửa sổ

1. Dùng shell trực tiếp kiểm tra:
   - `git status --short`
   - `git diff --check`
   - nhánh hiện tại và danh sách file đang sửa.
2. Khởi tạo Computer Use `@oai/sky` trong `node_repl`.
3. Gọi `sky.list_apps()` và tìm ứng dụng Antigravity.
4. Chỉ tiếp tục khi kết quả có đúng một cửa sổ Antigravity phù hợp.
5. Gọi `sky.get_window(...)`, kích hoạt cửa sổ và chụp state mới có accessibility text/screenshot.
6. Xác nhận cửa sổ đang mở đúng workspace `D:/App/AI/homeshare-dev-THE-on-dev`.

## Giai đoạn 2 — Nạp prompt cho Anti

1. Mở `tasks/antigravity_prompt.md` bằng shell trực tiếp để lấy prompt đã duyệt.
2. Trong state mới nhất của cửa sổ Anti, xác định chính xác ô chat/composer.
3. Click một lần vào ô nhập, refresh state và kiểm tra focused element.
4. Điền prompt nhưng chưa gửi.
5. Chụp state để xác minh nội dung và đúng workspace.
6. Xin người dùng xác nhận ngay trước khi bấm Send.
7. Sau xác nhận, bấm Send một lần và refresh state ngay.

## Giai đoạn 3 — Điều phối theo checkpoint

### Checkpoint A: Bộ lọc tầng/phòng

- Yêu cầu Anti viết test RED trước.
- Hoàn thiện helper lọc thuần và UI responsive.
- Codex kiểm tra diff, chạy focused test và analyzer bằng shell trực tiếp.
- Nếu chưa đạt, gửi follow-up ngắn chỉ rõ lỗi/test thất bại; không gửi lại toàn bộ prompt.

### Checkpoint B: Cọc 10–20%

- Yêu cầu Anti giữ một nguồn duy nhất `roomDepositPercentages = [10, 15, 20]`.
- Bắt buộc sửa `roomDeposit` để từ chối mọi tỷ lệ ngoài danh sách.
- Rà soát tạo phòng, sửa phòng, tạo bài đăng và provider validation.
- Codex chạy test biên 9/10/15/20/21/25 và analyzer.

### Checkpoint C: Checkout không sinh `isAvailable`

- Yêu cầu Anti viết test repository cho hai trường hợp còn cư dân/người cuối rời đi.
- Bỏ write `isAvailable` trực tiếp trong `CheckinCheckoutRepository.checkout`.
- Ngăn helper `restorePostOnCancelledBooking` được checkout gọi ghi `isAvailable: true` gián tiếp.
- Giữ nguyên hành vi hủy booking ngoài checkout.
- Codex kiểm tra document sau checkout không còn key `isAvailable`, nhưng `status` đúng.

### Checkpoint D: Tổng kiểm định

- Chạy focused tests.
- Chạy `flutter analyze` cho file đã đổi.
- Chạy full test suite nếu repo có test directory.
- Chạy `git diff --check` và rà diff theo file.
- Yêu cầu Anti cập nhật `tiendo.md` theo kết quả thật, không ghi “pass” nếu chưa chạy.

## Tiêu chí dừng và báo người dùng

- Anti yêu cầu lựa chọn nghiệp vụ ngoài ba yêu cầu hiện tại.
- Working tree xuất hiện file ngoài phạm vi mà Anti không giải thích được.
- Anti muốn commit/push, xóa dữ liệu hoặc reset thay đổi.
- Test/analyzer lỗi lặp lại sau hai lần follow-up.
- Computer Use không xác định được duy nhất cửa sổ Anti, mất focus hoặc state không chắc chắn.

## Bàn giao cuối

- Liệt kê file Anti đã sửa.
- Tóm tắt hành vi trước/sau.
- Báo đầy đủ test/analyzer đã chạy và lỗi còn lại.
- Xác nhận rõ: chưa commit, chưa push.
