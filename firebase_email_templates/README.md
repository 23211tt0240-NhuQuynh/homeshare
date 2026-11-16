# Mẫu email xác thực HomeShare

- Tên người gửi: `HomeShare`
- Tiêu đề: `[HomeShare] Xác thực tài khoản đăng ký`
- Nội dung HTML: `verify_email_vi.html`

Áp dụng tại Firebase Console → Authentication → Templates → Email address verification → Edit.

Giữ nguyên các placeholder Firebase sau khi dán nội dung:

- `%DISPLAY_NAME%`: tên người đăng ký.
- `%EMAIL%`: Gmail đang xác thực.
- `%LINK%`: link xác thực do Firebase tạo.

Firebase Verification Template không có placeholder ngày/giờ động. Thời gian chính xác được Gmail hiển thị ở phần đầu thư, vì vậy mẫu hướng dẫn người dùng xem tại đó.
