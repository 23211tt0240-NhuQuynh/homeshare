# BỘ QUY ƯỚC CHUẨN DỮ LIỆU CLOUD FIRESTORE (HOMESHARE)
> **Nguồn chân lý duy nhất (Single Source of Truth):** `Database.docx` / `SQL_NHOM4_CHUYENDEDIDONG.sql` / `lib/core/constants/firestore_collections.dart`.  
> **Nguyên tắc cốt lõi:** Làm việc **từ gốc đến ngọn** (Quy ước Schema $\rightarrow$ Model Dart $\rightarrow$ Giao diện UI). Mọi thành viên trong nhóm khi đọc, ghi dữ liệu Firebase bắt buộc phải tuân theo chuẩn này!

---

## 📌 NGUYÊN TẮC BẮT BUỘC DÀNH CHO CẢ NHÓM

1. **Chuẩn hóa 100% tiếng Anh (CamelCase):**  
   * Tên Collection: chữ thường, số nhiều hoặc danh từ nối gạch dưới (vd: `users`, `properties`, `rooms`, `posts`, `bookings`, `audit_logs`).
   * Tên Field: viết theo chuẩn `camelCase` (vd: `rentalPrice`, `depositAmount`, `phoneNumber`, `createdAt`).
   * Tuyệt đối **không tự ý đặt tên tiếng Việt mới** (như `gia_thue`, `tienCoc`, `diaChi`...). Nếu đọc dữ liệu cũ, chỉ dùng lớp mapper trong code để tương thích ngược.

2. **Quy trình thêm / sửa dữ liệu (Từ gốc đến ngọn):**
   * **Bước 1 (Gốc):** Thêm định nghĩa Collection / Field vào tài liệu này và file `firestore_collections.dart`.
   * **Bước 2 (Thân):** Cập nhật Model tương ứng (`fromMap`, `toMap`).
   * **Bước 3 (Ngọn):** Hiển thị và xử lý trên màn hình UI.

3. **Thời gian (Timestamp):**
   * Mọi trường thời gian tạo / cập nhật phải dùng `FieldValue.serverTimestamp()` khi ghi và ép kiểu thành `Timestamp` khi đọc.

---

## 🗂️ DANH MỤC CÁC COLLECTION VÀ SCHEMA CHI TIẾT

---

### 1. `users` — Bảng Người dùng
* **Khóa chính Document ID:** `uid` (Lấy từ Firebase Auth UID).

| Tên trường (Field) | Kiểu dữ liệu | Bắt buộc | Mô tả chi tiết |
|---|---|:---:|---|
| `uid` | String | Có | Khóa chính trùng khớp với Auth UID |
| `userCode` | String | Có | Mã người dùng (VD: `NT001`, `CT001`, `ADMIN01`) |
| `email` | String | Có | Email tài khoản (viết thường) |
| `displayName` | String | Có | Họ và tên hiển thị |
| `phoneNumber` | String | Có | Số điện thoại liên hệ |
| `role` | String | Có | `'renter'` (Người thuê) \| `'host'` (Chủ trọ) \| `'admin'` (Quản trị) |
| `roleId` | int | Có | `1`: Renter \| `2`: Host \| `3`: Admin |
| `avatarUrl` | String | Không | Link ảnh đại diện từ Firebase Storage |
| `address` | String | Không | Địa chỉ thường trú / tạm trú |
| `hometown` | String | Không | Quê quán |
| `reputationScore` | int | Có | Điểm uy tín người dùng (Mặc định: 100) |
| `statusId` | int | Có | `1`: Hoạt động \| `2`: Bị khóa / Bị cấm |
| `isBanned` | bool | Có | Trạng thái khóa tài khoản (`true` / `false`) |
| `accountDeleted` | bool | Có | Đánh dấu xóa tài khoản (`true` / `false`) |
| `createdAt` | Timestamp | Có | Thời gian tạo tài khoản |

---

### 2. `properties` — Bảng Nhà trọ / Cơ sở bất động sản
* **Khóa chính Document ID:** `propertyId` (Auto ID hoặc UUID).

| Tên trường (Field) | Kiểu dữ liệu | Bắt buộc | Mô tả chi tiết |
|---|---|:---:|---|
| `propertyId` | String | Có | Khóa chính cơ sở |
| `hostId` | String | Có | Khóa ngoại liên kết `users.uid` của Chủ trọ |
| `name` | String | Có | Tên nhà trọ / tòa nhà (VD: "Nhà trọ Hoa Hồng") |
| `address` | String | Có | Địa chỉ số nhà, tên đường |
| `city` (hoặc `province`) | String | Có | Tỉnh / Thành phố |
| `district` | String | Có | Quận / Huyện |
| `ward` | String | Có | Phường / Xã |
| `description` | String | Không | Mô tả quy mô cơ sở trọ |
| `floors` | int | Không | Tổng số tầng |
| `plannedRooms` | int | Không | Số lượng phòng dự kiến |
| `images` | List<String> | Không | Danh sách URL ảnh chụp cơ sở |
| `status` | String | Có | `'active'`, `'pending'`, `'inactive'` |
| `createdAt` | Timestamp | Có | Thời gian tạo |

---

### 3. `rooms` — Bảng Phòng trọ chi tiết
* **Khóa chính Document ID:** `roomId` (Auto ID hoặc UUID).

| Tên trường (Field) | Kiểu dữ liệu | Bắt buộc | Mô tả chi tiết |
|---|---|:---:|---|
| `roomId` | String | Có | Khóa chính phòng trọ |
| `propertyId` | String | Có | Khóa ngoại liên kết `properties.propertyId` |
| `hostId` | String | Có | Khóa ngoại liên kết `users.uid` của Chủ trọ |
| `roomCode` | String | Có | Mã phòng / Số phòng (VD: "P.101", "P.202") |
| `title` | String | Có | Tiêu đề tóm tắt phòng |
| `description` | String | Không | Mô tả tiện ích, quy định phòng |
| `floor` | int | Có | Tầng của phòng |
| `area` | double / num | Có | Diện tích phòng (m²) |
| `capacity` | int | Có | Sức chứa tối đa (số người) |
| `rentalPrice` | double / num | Có | Giá thuê theo tháng (VNĐ) |
| `depositAmount` | double / num | Có | Tiền đặt cọc theo phòng (VNĐ) |
| `electricityRate` | double / num | Không | Giá điện (VNĐ/kWh) |
| `waterRate` | double / num | Không | Giá nước (VNĐ/m³ hoặc người) |
| `wifiRate` | double / num | Không | Giá internet / wifi |
| `amenities` | List<String> | Có | Danh sách tiện ích (VD: `['wifi', 'aircon', 'bed']`) |
| `images` | List<String> | Có | Danh sách URL hình ảnh phòng |
| `status` | String | Có | `'available'`, `'occupied'`, `'reserved'`, `'deleted'` |
| `createdAt` | Timestamp | Có | Thời gian tạo phòng |

---

### 4. `posts` — Bảng Bài đăng cho thuê
* **Khóa chính Document ID:** `postId` (Auto ID).

| Tên trường (Field) | Kiểu dữ liệu | Bắt buộc | Mô tả chi tiết |
|---|---|:---:|---|
| `postId` | String | Có | Khóa chính bài đăng |
| `roomId` | String | Có | Khóa ngoại liên kết `rooms.roomId` |
| `hostId` | String | Có | Khóa ngoại liên kết `users.uid` của chủ đăng |
| `title` | String | Có | Tiêu đề bài đăng hiển thị trên trang chủ |
| `description` | String | Có | Nội dung mô tả chi tiết |
| `rentalPrice` | double / num | Có | Giá thuê phòng hiển thị (VNĐ/tháng) |
| `depositAmount` | double / num | Có | Tiền đặt cọc hiển thị |
| `depositPercentage`| int | Có | % cọc (10 - 100, bước 10) |
| `address` | String | Có | Địa chỉ chi tiết phòng trọ |
| `contactPhone` | String | Có | Số điện thoại liên hệ xem phòng |
| `amenities` | List<String> | Có | Danh sách tiện ích |
| `images` | List<String> | Có | Danh sách ảnh hiển thị trên bài |
| `status` | String | Có | `'pending'`, `'active'`, `'rejected'`, `'hidden'` |
| `createdAt` | Timestamp | Có | Thời gian đăng bài |

---

### 5. `bookings` — Bảng Đơn đặt phòng & Giữ cọc
* **Khóa chính Document ID:** `bookingId` (Auto ID hoặc mã đơn).

| Tên trường (Field) | Kiểu dữ liệu | Bắt buộc | Mô tả chi tiết |
|---|---|:---:|---|
| `bookingId` | String | Có | Khóa chính đơn đặt |
| `roomId` | String | Có | Khóa ngoại liên kết `rooms.roomId` |
| `hostId` | String | Có | Khóa ngoại chủ nhà nhận đơn |
| `renterId` (hoặc `userId`)| String | Có | Khóa ngoại người đặt phòng |
| `renterName` | String | Có | Tên người đặt phòng |
| `renterPhone` | String | Có | SĐT người đặt phòng |
| `roomTitle` | String | Không | Tên phòng hỗ trợ hiển thị nhanh |
| `rentalPrice` | double / num | Có | Giá thuê thỏa thuận |
| `depositAmount` | double / num | Có | Tiền cọc thanh toán |
| `totalAmount` | double / num | Có | Tổng tiền giao dịch |
| `isPaid` | bool | Có | Đã thanh toán tiền cọc chưa (`true` / `false`) |
| `status` | String | Có | `'pending'`, `'approved'`, `'paid'`, `'completed'`, `'cancelled'` |
| `subTag` | String | Không | Nhãn phụ trạng thái (VD: `'daCoc'`, `'dangO'`) |
| `checkInDate` | Timestamp / String | Có | Ngày dự kiến dọn vào |
| `createdAt` | Timestamp | Có | Thời gian tạo đơn |
| `approvedAt` | Timestamp | Không | Thời gian Admin / Chủ nhà duyệt |

---

### 6. `host_reviews` — Bảng Đánh giá Chủ trọ
* **Khóa chính Document ID:** `bookingId` (Dùng luôn ID đơn thuê để đảm bảo 1 đơn chỉ đánh giá 1 lần).

| Tên trường (Field) | Kiểu dữ liệu | Bắt buộc | Mô tả chi tiết |
|---|---|:---:|---|
| `bookingId` | String | Có | Khóa ngoại đơn đặt cọc tương ứng |
| `hostId` | String | Có | Khóa ngoại chủ trọ được đánh giá |
| `reviewerId` | String | Có | Khóa ngoại người đánh giá (`request.auth.uid`) |
| `reviewerName` | String | Có | Tên người đánh giá |
| `rating` | num (1-5) | Có | Số sao đánh giá (1.0 đến 5.0) |
| `comment` | String | Có | Nội dung nhận xét (tối đa 500 ký tự) |
| `createdAt` | Timestamp | Có | Thời gian gửi đánh giá |

---

### 7. `system_configs` — Bảng Cấu hình hệ thống (Bảo trì)
* **Document duy nhất:** `maintenance_config`

| Tên trường (Field) | Kiểu dữ liệu | Bắt buộc | Mô tả chi tiết |
|---|---|:---:|---|
| `is_maintenance` | bool | Có | Công tắc bật (`true`) / tắt (`false`) bảo trì |
| `message` | String | Có | Lời nhắn gửi người dùng khi đang bảo trì |
| `expected_completion` | String (ISO-8601)| Có | Giờ dự kiến xong (VD: `'2026-11-01T15:30:00Z'`) |
| `allowed_roles` | List<String> | Có | Danh sách vai trò được vào khi bảo trì (mặc định: `['quan_tri_vien']`) |
| `updated_at` | Timestamp | Có | Thời gian cập nhật công tắc |
| `updated_by` | String | Có | Tên Admin thực hiện |
| `updated_by_id` | String | Có | UID của Admin thực hiện |

---

### 8. `admin_access` — Bảng Cấp phép truy cập Admin (2-Lớp)
* **Khóa chính Document ID:** `uid` (UID của Admin được cấp phép).

| Tên trường (Field) | Kiểu dữ liệu | Bắt buộc | Mô tả chi tiết |
|---|---|:---:|---|
| `uid` | String | Có | UID của tài khoản Admin |
| `adminName` | String | Có | Tên của Admin |
| `enabled` | bool | Có | `true`: Được vào Admin \| `false`: Bị tước quyền |
| `updatedByUid` | String | Có | UID Manager thực hiện cấp/tước quyền |
| `updatedByEmail` | String | Có | Email Manager thực hiện |
| `updatedAt` | Timestamp | Có | Thời gian thay đổi |

---

### 9. `audit_logs` — Bảng Nhật ký kiểm toán (Truy vết thao tác Admin)
* **Khóa chính Document ID:** Auto ID.

| Tên trường (Field) | Kiểu dữ liệu | Bắt buộc | Mô tả chi tiết |
|---|---|:---:|---|
| `actor` / `adminName`| String | Có | Họ tên Admin thực hiện |
| `actorUid` / `adminId`| String | Có | UID Admin thực hiện |
| `action` / `title` | String | Có | Tên hành động (Duyệt bài, Duyệt cọc, Bật bảo trì, Khóa user...) |
| `category` | String | Có | Phân loại: `'system'`, `'taiChinh'`, `'post'`, `'nguoiDung'` |
| `details` / `subtitle`| String | Có | Chi tiết nội dung hành động |
| `target` | String | Không | Đối tượng bị tác động (Mã đơn, mã bài, UID user) |
| `createdAt` / `timestamp`| Timestamp | Có | Thời gian máy chủ ghi nhận |

---

### 10. `reports` — Bảng Báo cáo vi phạm bài đăng
* **Khóa chính Document ID:** Auto ID.

| Tên trường (Field) | Kiểu dữ liệu | Bắt buộc | Mô tả chi tiết |
|---|---|:---:|---|
| `reportId` | String | Có | Khóa chính báo cáo |
| `roomId` / `postId`| String | Có | Mã phòng hoặc mã bài đăng bị tố cáo |
| `reporterId` | String | Có | UID người gửi tố cáo |
| `reason` | String | Có | Lý do báo cáo vi phạm |
| `status` | String | Có | Trạng thái xử lý: `'pending'`, `'resolved'`, `'dismissed'` |
| `createdAt` | Timestamp | Có | Thời gian gửi báo cáo |

---

## 🚫 CÁC LỖI TỐI KỴ CẦN TRÁNH
1. ❌ **Không tự tạo Collection mới ngoài danh sách trên** khi chưa bàn bạc với nhóm.
2. ❌ **Không trộn lẫn ngôn ngữ**: Tránh viết nửa Anh nửa Việt (như `giaRental`, `phong_code`).
3. ❌ **Không lưu kiểu dữ liệu sai lệch**:
   * Tiền bạc (`rentalPrice`, `depositAmount`): Bắt buộc là `num` (int / double), tuyệt đối **không lưu String dạng `"3.500.000"`** vào database (định dạng dấu chấm/phẩy chỉ để hiển thị trên UI).
   * Điểm uy tín (`reputationScore`): Bắt buộc là `int`.
   * Trạng thái boolean (`isPaid`, `isBanned`): Bắt buộc là `bool` (`true`/`false`), không lưu String `"true"` hay số `1/0`.

---
*Tệp quy ước này được lưu trực tiếp tại `docs/quy-uoc-firestore.md` để toàn bộ nhóm làm việc thống nhất.*
