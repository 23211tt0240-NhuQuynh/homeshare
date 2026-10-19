/// Centralized Firestore schema definition based strictly on Database.docx.
/// 
/// Rule: All collections and field names stored in Firestore MUST match the agreed
/// Database.docx schema. No new collections or ad-hoc fields are allowed.
/// Code uses English variable names; Firestore mapper maps to fixed schema keys.
library;

/// Tên các collection hợp lệ duy nhất trong Firestore theo Database.docx
abstract final class FirestoreCollections {
  static const users = 'users';
  static const bankAccounts = 'bank_accounts';
  static const properties = 'properties';
  static const rooms = 'rooms';
  static const amenities = 'amenities';
  static const locations = 'locations';
  static const posts = 'posts';
  static const bookings = 'bookings';

  // Nghiệp vụ quản lý vận hành kỳ ở, bàn giao, nhận phòng & vi phạm
  static const periods = 'periods';
  static const kyO = 'periods';
  static const checkins = 'checkins';
  static const residents = 'residents';
  static const handoverItems = 'handover_items';
  static const checkoutRecords = 'checkout_records';
  static const violations = 'violations';
  static const invoiceLines = 'invoice_lines';
  static const violationRecords = 'violation_records';

  // Role Host English Subcollections & Root Collections
  static const rentalPosts = 'rental_posts';
  static const postReports = 'post_reports';
  static const escrowDeposits = 'escrow_deposits';
  static const checkinRecords = 'checkin_records';
  static const residentVehicles = 'resident_vehicles';
  static const hostSettlements = 'host_settlements';
  static const idVerifications = 'id_verifications';
  static const favoriteRooms = 'favorite_rooms';

  // Thông báo & Thanh toán
  static const notifications = 'notifications';
  static const payments = 'payments';

  // Bảng liên kết & thực thể theo ERD Database (Tiện ích phòng, Ảnh phòng, Ảnh trọ)
  static const roomAmenities = 'room_amenities';
  static const tienIchPhong = 'TienIch_Phong';
  static const roomImages = 'room_images';
  static const anhPhong = 'AnhPhong';
  static const propertyImages = 'property_images';
  static const anhTro = 'AnhTro';
  static const rentalTypes = 'rental_types';
  static const loaiThue = 'LoaiThue';
  static const roomStatuses = 'room_statuses';
  static const trangThaiPhong = 'TrangThaiPhong';
  static const postStatuses = 'post_statuses';
  static const trangThai = 'TrangThai';

  // Các bảng chuẩn theo SQL_NHOM4_CHUYENDEDIDONG.sql
  static const nguoiDung = 'nguoi_dung';
  static const xacThucCccd = 'xac_thuc_cccd';
  static const batDongSan = 'bat_dong_san';
  static const phongTro = 'phong_tro';
  static const danhMucTienIch = 'danh_muc_tien_ich';
  static const tienIchPhongTro = 'tien_ich_phong_tro';
  static const hinhAnhPhong = 'hinh_anh_phong';
  static const baiDangChoThue = 'bai_dang_cho_thue';
  static const baoCaoViPhamBaiDang = 'bao_cao_vi_pham_bai_dang';
  static const phongTroYeuThich = 'phong_tro_yeu_thich';
  static const hoSoLoiSongCuDan = 'ho_so_loi_song_cu_dan';
  static const baiDangTimOGhep = 'bai_dang_tim_o_ghep';
  static const loiMoiOGhep = 'loi_moi_o_ghep';
  static const donDatPhong = 'don_dat_phong';
  static const giaoDichGiuCoc = 'giao_dich_giu_coc';
  static const cuDanDangO = 'cu_dan_dang_o';
  static const phuongTienCuDan = 'phuong_tien_cu_dan';
  static const bienBanNhanPhongCheckin = 'bien_ban_nhan_phong_checkin';
  static const bienBanTraPhongCheckout = 'bien_ban_tra_phong_checkout';
  static const nhatKyViPhamNoiQuy = 'nhat_ky_vi_pham_noi_quy';
  static const cuocTroChuyen = 'cuoc_tro_chuyen';
  static const tinNhan = 'tin_nhan';
  static const thongBao = 'thong_bao';
  static const quyetToanChuTro = 'quyet_toan_chu_tro';
  static const nhatKyKiemToanHeThong = 'nhat_ky_kiem_toan_he_thong';

  // Backward compatibility alias: publicRooms & hostRooms
  static const publicRooms = 'rooms';
  static const hostRooms = 'host_rooms';
  static const hostProperties = 'properties';
}

/// Schema các trường cho collection `posts` (Bảng Bài đăng)
abstract final class PostFields {
  /// Khóa chính document bài đăng [PK]
  static const postId = 'postId';

  /// Khóa ngoại liên kết phòng trọ trong `rooms` [FK] - Bắt buộc (String)
  static const roomId = 'roomId';

  /// Khóa ngoại liên kết chủ nhà trong `users` [FK] - Bắt buộc (String)
  static const hostId = 'hostId';

  /// Khóa ngoại liên kết địa điểm trong `locations` [FK] - Bắt buộc (String)
  static const locationId = 'locationId';

  /// Khóa ngoại loại thuê (thang, ngay, ...) [FK] - Bắt buộc (String)
  static const rentalTypeId = 'rentalTypeId';

  /// Khóa ngoại trạng thái bài đăng [FK] - Bắt buộc (String)
  static const statusId = 'statusId';

  /// Tiêu đề bài đăng - Bắt buộc (String)
  static const title = 'title';

  /// Mô tả chi tiết - Bắt buộc (String)
  static const description = 'description';

  /// Giá thuê theo tháng (VNĐ) - Bắt buộc (double/num)
  static const rentalPrice = 'rentalPrice';

  /// Tiền đặt cọc (VNĐ) - Bắt buộc (double/num)
  static const depositAmount = 'depositAmount';

  /// Phần trăm tiền cọc: 10–100, bước 10 - Bắt buộc (int)
  static const depositPercentage = 'depositPercentage';

  /// Danh sách tiện ích phòng - Tùy chọn (`List<String>`)
  static const amenities = 'amenities';

  /// Danh sách URL ảnh phòng - Tùy chọn (`List<String>`)
  static const images = 'images';

  /// Địa chỉ chi tiết - Bắt buộc (String)
  static const address = 'address';

  /// Số điện thoại liên hệ - Bắt buộc (String)
  static const contactPhone = 'contactPhone';

  /// Thời gian đăng bài - Bắt buộc (Timestamp)
  static const createdAt = 'createdAt';

  /// Trạng thái hiển thị (tùy chọn) (String)
  static const status = 'status';

  // --- Legacy Vietnamese aliases để đọc dữ liệu cũ nếu có ---
  static const legacyPostId = 'baiDangId';
  static const legacyRoomId = 'phongId';
  static const legacyHostId = 'chuNhaId';
  static const legacyLocationId = 'diaDiemId';
  static const legacyRentalTypeId = 'loaiThue_id';
  static const legacyStatusId = 'trangThai_id';
  static const legacyTitle = 'tieuDe';
  static const legacyDescription = 'moTa';
  static const legacyRentalPrice = 'giaThue';
  static const legacyDepositAmount = 'tienCoc';
  static const legacyDepositPercentage = 'phanTramTienCoc';
  static const legacyAmenities = 'tienIch';
  static const legacyImages = 'anhPhong';
  static const legacyAddress = 'diaChi';
  static const legacyContactPhone = 'soDienThoaiLienHe';
  static const legacyCreatedAt = 'ngayDang';
  static const legacyStatus = 'trangThai';

  /// Tập hợp toàn bộ các trường hợp lệ được phép ghi vào document `posts`
  static const allowedWriteFields = {
    postId,
    roomId,
    hostId,
    locationId,
    rentalTypeId,
    statusId,
    title,
    description,
    rentalPrice,
    depositAmount,
    depositPercentage,
    amenities,
    images,
    address,
    contactPhone,
    createdAt,
    status,
  };
}

/// Schema các trường cho collection `rooms` (Bảng Phòng)
abstract final class RoomFields {
  /// Khóa chính document phòng [PK] (String)
  static const roomId = 'roomId';

  /// Khóa ngoại liên kết cơ sở trong `properties` [FK] - Bắt buộc (String)
  static const propertyId = 'propertyId';

  /// Khóa ngoại liên kết chủ nhà trong `users` [FK] - Bắt buộc (String)
  static const hostId = 'hostId';

  /// Số phòng / mã phòng - Bắt buộc (String)
  static const roomCode = 'roomCode';

  /// Tầng của phòng - Bắt buộc (int)
  static const floor = 'floor';

  /// Diện tích (m²) - Bắt buộc (double/num)
  static const area = 'area';

  /// Sức chứa tối đa (người) - Bắt buộc (int)
  static const capacity = 'capacity';

  /// Giá thuê phòng (VNĐ/tháng) - Bắt buộc (double/num)
  static const rentalPrice = 'rentalPrice';

  /// Tiền đặt cọc phòng (VNĐ) - Bắt buộc (double/num)
  static const depositAmount = 'depositAmount';

  /// Khóa ngoại trạng thái phòng [FK] (String)
  static const statusId = 'statusId';

  /// Trạng thái phòng: available, occupied, reserved, deleted (String)
  static const status = 'status';

  /// Danh sách tiện ích của phòng (`List<String>`)
  static const amenities = 'amenities';

  /// Danh sách URL ảnh của phòng (`List<String>`)
  static const images = 'images';

  /// Mô tả phòng (String)
  static const description = 'description';

  /// Tiêu đề phòng (String)
  static const title = 'title';

  /// Địa chỉ phòng (String)
  static const address = 'address';

  /// Thời gian tạo phòng (Timestamp)
  static const createdAt = 'createdAt';

  // Legacy Vietnamese aliases
  static const legacyRoomId = 'phongId';
  static const legacyPropertyId = 'nhaTroId';
  static const legacyHostId = 'chuNhaId';
  static const legacyRoomCode = 'soPhong';
  static const legacyFloor = 'tang';
  static const legacyArea = 'dienTich';
  static const legacyCapacity = 'sucChua';
  static const legacyRentalPrice = 'giaThue';
  static const legacyDepositAmount = 'tienCoc';
  static const legacyStatusId = 'trangThai_id';
  static const legacyStatus = 'trangThai';
  static const legacyAmenities = 'tienIch';
  static const legacyImages = 'anhPhong';
  static const legacyDescription = 'moTa';
  static const legacyTitle = 'tieuDe';
  static const legacyAddress = 'diaChi';
  static const legacyCreatedAt = 'ngayTao';
}

/// Schema các trường cho collection `properties` (Bảng Nhà trọ / Bất động sản)
abstract final class PropertyFields {
  /// Khóa chính document cơ sở [PK] (String)
  static const propertyId = 'propertyId';

  /// Khóa ngoại liên kết chủ nhà trong `users` [FK] - Bắt buộc (String)
  static const hostId = 'hostId';

  /// Khóa ngoại liên kết địa điểm trong `locations` [FK] (String)
  static const locationId = 'locationId';

  /// Tên nhà trọ / cơ sở - Bắt buộc (String)
  static const name = 'name';

  /// Địa chỉ chi tiết - Bắt buộc (String)
  static const address = 'address';

  /// Tỉnh / Thành phố (String)
  static const city = 'city';

  /// Tỉnh / Thành phố (alias province như trong thực tế Firestore)
  static const province = 'province';

  /// Quận / Huyện (String)
  static const district = 'district';

  /// Phường / Xã (String)
  static const ward = 'ward';

  /// Thời gian tạo (Timestamp)
  static const createdAt = 'createdAt';

  /// Trạng thái cơ sở (String)
  static const status = 'status';

  // Legacy aliases
  static const legacyPropertyId = 'nhaTroId';
  static const legacyHostId = 'chuNhaId';
  static const legacyLocationId = 'diaDiemId';
  static const legacyName = 'ten';
  static const legacyAddress = 'diaChi';
  static const legacyCity = 'thanhPho';
  static const legacyDistrict = 'quanHuyen';
  static const legacyWard = 'phuongXa';
  static const legacyCreatedAt = 'ngayTao';
  static const legacyStatus = 'trangThai';
}

/// Schema các trường cho collection `amenities` (Bảng Tiện ích)
abstract final class AmenityFields {
  /// Khóa chính tiện ích [PK] (String)
  static const amenityId = 'amenityId';

  /// Tên tiện ích - Bắt buộc (String)
  static const name = 'name';

  // Legacy aliases
  static const legacyAmenityId = 'tienIchId';
  static const legacyName = 'tenTienIch';
}

/// Schema các trường cho collection `locations` (Bảng Địa điểm)
abstract final class LocationFields {
  /// Khóa chính địa điểm [PK] (String)
  static const locationId = 'locationId';

  /// PlaceId (String)
  static const placeId = 'placeId';

  /// Khóa ngoại liên kết bài đăng (String)
  static const postId = 'postId';

  /// Địa chỉ (String)
  static const address = 'address';

  /// Tỉnh / Thành phố - Bắt buộc (String)
  static const city = 'city';

  /// Tỉnh / Thành phố (province)
  static const province = 'province';

  /// Quận / Huyện (String)
  static const district = 'district';

  /// Phường / Xã (String)
  static const ward = 'ward';

  /// Tọa độ vĩ độ
  static const latitude = 'latitude';

  /// Tọa độ kinh độ
  static const longitude = 'longitude';

  // Legacy aliases
  static const legacyLocationId = 'diaDiemId';
  static const legacyCity = 'thanhPho';
  static const legacyDistrict = 'quanHuyen';
  static const legacyWard = 'phuongXa';
}

/// Schema các trường cho collection `users` (Bảng Người dùng)
abstract final class UserFields {
  /// Khóa chính người dùng [PK] (String)
  static const userId = 'userId';

  /// Họ tên người dùng (String)
  static const displayName = 'displayName';

  /// Email (String)
  static const email = 'email';

  /// Số điện thoại (String)
  static const phoneNumber = 'phoneNumber';

  /// Vai trò người dùng (String)
  static const role = 'role';

  /// Khóa ngoại vai trò [FK] (String)
  static const roleId = 'roleId';

  /// URL ảnh đại diện (String)
  static const avatarUrl = 'avatarUrl';

  // Legacy aliases
  static const legacyUserId = 'nguoiDungId';
  static const legacyDisplayName = 'hoTen';
  static const legacyPhoneNumber = 'soDienThoai';
  static const legacyRole = 'vaiTro';
  static const legacyRoleId = 'vaiTro_id';
  static const legacyAvatarUrl = 'anhDaiDien';
}

/// Schema các trường cho collection `bookings` (Bảng Đơn đặt phòng)
abstract final class BookingFields {
  /// Khóa chính đơn đặt phòng [PK] (String)
  static const bookingId = 'bookingId';

  /// Khóa ngoại phòng [FK] (String)
  static const roomId = 'roomId';

  /// Khóa ngoại chủ nhà [FK] (String)
  static const hostId = 'hostId';

  /// Khóa ngoại người đặt phòng [FK] (String)
  static const userId = 'userId';

  /// Khóa ngoại trạng thái đơn phòng [FK] (String)
  static const statusId = 'statusId';

  /// Tiền đặt cọc (double)
  static const depositAmount = 'depositAmount';

  /// Giá thuê (double)
  static const rentalPrice = 'rentalPrice';

  /// Thời gian tạo đơn (Timestamp)
  static const createdAt = 'createdAt';

  // Legacy aliases
  static const legacyBookingId = 'donId';
  static const legacyRoomId = 'phongId';
  static const legacyHostId = 'chuNhaId';
  static const legacyUserId = 'nguoiDungId';
  static const legacyStatusId = 'trangThai_id';
  static const legacyDepositAmount = 'tienCoc';
  static const legacyRentalPrice = 'giaThue';
  static const legacyCreatedAt = 'ngayTao';
}

/// Schema các trường cho collection `notifications` (Bảng Thông báo)
abstract final class NotificationFields {
  /// Khóa chính document thông báo [PK] (String)
  static const notificationId = 'notificationId';

  /// Khóa ngoại người nhận [FK] (String)
  static const receiverId = 'receiverId';

  /// Khóa ngoại người gửi [FK] (String)
  static const senderId = 'senderId';

  /// Loại thông báo: deposit, pendingAction, paymentCompleted (String)
  static const notificationType = 'notificationType';

  /// Tiêu đề thông báo (String)
  static const title = 'title';

  /// Nội dung thông báo (String)
  static const message = 'message';

  /// Khóa ngoại liên kết đơn đặt phòng [FK] (String)
  static const bookingId = 'bookingId';

  /// Khóa ngoại liên kết thanh toán [FK] (String)
  static const paymentId = 'paymentId';

  /// Khóa ngoại liên kết phòng [FK] (String)
  static const roomId = 'roomId';

  /// Khóa ngoại liên kết cơ sở/nhà trọ [FK] (String)
  static const propertyId = 'propertyId';

  /// Số tiền liên quan (double)
  static const amount = 'amount';

  /// Khóa ngoại trạng thái thông báo [FK] (String)
  static const statusId = 'statusId';

  /// Đã đọc chưa (bool)
  static const isRead = 'isRead';

  /// Thời gian tạo (Timestamp)
  static const createdAt = 'createdAt';

  /// Thời gian cập nhật (Timestamp)
  static const updatedAt = 'updatedAt';

  // Thông tin hỗ trợ hiển thị giao diện & điều chỉnh cọc theo Figma
  static const bookingCode = 'bookingCode';
  static const roomCode = 'roomCode';
  static const roomTitle = 'roomTitle';
  static const renterName = 'renterName';
  static const checkInDate = 'checkInDate';
  static const oldRoomId = 'oldRoomId';
  static const newRoomId = 'newRoomId';
  static const oldCheckInDate = 'oldCheckInDate';
  static const newCheckInDate = 'newCheckInDate';
  static const adjustmentReason = 'adjustmentReason';
  static const paymentMethod = 'paymentMethod';

  // Legacy Vietnamese aliases
  static const legacyNotificationId = 'thongBaoId';
  static const legacyReceiverId = 'nguoiNhanId';
  static const legacySenderId = 'nguoiGuiId';
  static const legacyNotificationType = 'loaiThongBao';
  static const legacyTitle = 'tieuDe';
  static const legacyMessage = 'noiDung';
  static const legacyBookingId = 'donId';
  static const legacyPaymentId = 'thanhToanId';
  static const legacyRoomId = 'phongId';
  static const legacyPropertyId = 'nhaTroId';
  static const legacyAmount = 'soTien';
  static const legacyStatusId = 'trangThai_id';
  static const legacyIsRead = 'daDoc';
  static const legacyCreatedAt = 'ngayTao';
  static const legacyUpdatedAt = 'ngayCapNhat';
}

/// Schema các trường cho collection `payments` (Bảng Thanh toán)
abstract final class PaymentFields {
  static const paymentId = 'paymentId';
  static const bookingId = 'bookingId';
  static const userId = 'userId';
  static const hostId = 'hostId';
  static const roomId = 'roomId';
  static const propertyId = 'propertyId';
  static const amount = 'amount';
  static const paymentMethod = 'paymentMethod';
  static const paymentType = 'paymentType';
  static const status = 'status';
  static const statusId = 'statusId';
  static const transactionCode = 'transactionCode';
  static const createdAt = 'createdAt';
  static const completedAt = 'completedAt';

  // Legacy aliases
  static const legacyPaymentId = 'thanhToanId';
  static const legacyBookingId = 'donId';
  static const legacyUserId = 'nguoiDungId';
  static const legacyAmount = 'soTien';
  static const legacyPaymentMethod = 'phuongThucThanhToan';
  static const legacyStatus = 'trangThai';
  static const legacyCreatedAt = 'ngayTao';
}

/// Schema các trường cho collection `room_amenities` / `TienIch_Phong` (Bảng liên kết Tiện ích - Phòng)
abstract final class RoomAmenityFields {
  static const id = 'id';
  static const roomId = 'roomId';
  static const amenityId = 'amenityId';
  static const inUse = 'inUse';
  static const amenityName = 'amenityName';
  static const createdAt = 'createdAt';

  // Legacy Vietnamese aliases theo ERD Database
  static const legacyRoomId = 'phongId';
  static const legacyAmenityId = 'tienIch_Id';
  static const legacyInUse = 'suDung';
  static const legacyAmenityName = 'tenTienIch';
}

/// Schema các trường cho collection `room_images` / `AnhPhong` (Bảng Ảnh phòng)
abstract final class RoomImageFields {
  static const id = 'id';
  static const roomId = 'roomId';
  static const url = 'url';
  static const imageType = 'imageType';
  static const sortOrder = 'sortOrder';
  static const createdAt = 'createdAt';

  // Legacy Vietnamese aliases theo ERD Database
  static const legacyRoomId = 'phongId';
  static const legacyUrl = 'duongDan';
  static const legacyImageType = 'loaiAnh';
  static const legacySortOrder = 'thuTu';
}

/// Schema các trường cho collection `property_images` / `AnhTro` (Bảng Ảnh nhà trọ)
abstract final class PropertyImageFields {
  static const id = 'id';
  static const propertyId = 'propertyId';
  static const url = 'url';
  static const imageType = 'imageType';
  static const createdAt = 'createdAt';

  // Legacy Vietnamese aliases theo ERD Database
  static const legacyPropertyId = 'nhaTro_Id';
  static const legacyPropertyIdAlt = 'nhaTroId';
  static const legacyUrl = 'duongDan';
  static const legacyImageType = 'loaiAnh';
}

/// 1. Schema trường bảng `bat_dong_san` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class BatDongSanSqlFields {
  static const id = 'id';
  static const chuTroId = 'chu_tro_id';
  static const tenToaNha = 'ten_toa_nha';
  static const diaChiChiTiet = 'dia_chi_chi_tiet';
  static const tinhThanh = 'tinh_thanh';
  static const quanHuyen = 'quan_huyen';
  static const phuongXa = 'phuong_xa';
  static const moTa = 'mo_ta';
  static const ngayTao = 'ngay_tao';
}

/// 2. Schema trường bảng `phong_tro` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class PhongTroSqlFields {
  static const id = 'id';
  static const batDongSanId = 'bat_dong_san_id';
  static const maPhong = 'ma_phong';
  static const dienTich = 'dien_tich';
  static const giaThue = 'gia_thue';
  static const tienCoc = 'tien_coc';
  static const giaDien = 'gia_dien';
  static const giaNuoc = 'gia_nuoc';
  static const giaWifi = 'gia_wifi';
  static const trangThai = 'trang_thai';
  static const ngayTao = 'ngay_tao';
}

/// 3. Schema trường bảng `danh_muc_tien_ich` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class DanhMucTienIchSqlFields {
  static const id = 'id';
  static const tenTienIch = 'ten_tien_ich';
  static const bieuTuong = 'bieu_tuong';
}

/// 4. Schema trường bảng `tien_ich_phong_tro` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class TienIchPhongTroSqlFields {
  static const id = 'id';
  static const phongTroId = 'phong_tro_id';
  static const tienIchId = 'tien_ich_id';
  static const tenTienIch = 'ten_tien_ich';
  static const ngayTao = 'ngay_tao';
}

/// 5. Schema trường bảng `hinh_anh_phong` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class HinhAnhPhongSqlFields {
  static const id = 'id';
  static const phongTroId = 'phong_tro_id';
  static const urlAnh = 'url_anh';
  static const laAnhChinh = 'la_anh_chinh';
  static const thuTu = 'thu_tu';
  static const ngayTao = 'ngay_tao';
}

/// 6. Schema trường bảng `bai_dang_cho_thue` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class BaiDangChoThueSqlFields {
  static const id = 'id';
  static const phongTroId = 'phong_tro_id';
  static const tieuDe = 'tieu_de';
  static const noiDung = 'noi_dung';
  static const trangThai = 'trang_thai';
  static const laBaiGhim = 'la_bai_ghim';
  static const ngayTao = 'ngay_tao';
  static const chuTroId = 'chu_tro_id';
}

/// 7. Schema trường bảng `don_dat_phong` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class DonDatPhongSqlFields {
  static const id = 'id';
  static const phongTroId = 'phong_tro_id';
  static const nguoiThueId = 'nguoi_thue_id';
  static const tienCoc = 'tien_coc';
  static const ngayDuKienDen = 'ngay_du_kien_den';
  static const trangThai = 'trang_thai';
  static const ngayTao = 'ngay_tao';
}

/// 8. Schema trường bảng `cu_dan_dang_o` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class CuDanDangOSqlFields {
  static const id = 'id';
  static const phongTroId = 'phong_tro_id';
  static const nguoiDungId = 'nguoi_dung_id';
  static const ngayBatDau = 'ngay_bat_dau';
  static const ngayKetThuc = 'ngay_ket_thuc';
  static const trangThai = 'trang_thai';
}

/// 9. Schema trường bảng `bien_ban_nhan_phong_checkin` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class BienBanCheckinSqlFields {
  static const id = 'id';
  static const donDatPhongId = 'don_dat_phong_id';
  static const chiSoDienBanDau = 'chi_so_dien_ban_dau';
  static const chiSoNuocBanDau = 'chi_so_nuoc_ban_dau';
  static const tinhTrangCoSoVatChat = 'tinh_trang_co_so_vat_chat';
  static const maQrCheckin = 'ma_qr_checkin';
  static const xacNhanNguoiThue = 'xac_nhan_nguoi_thue';
  static const ngayCheckin = 'ngay_checkin';
}

/// 10. Schema trường bảng `bien_ban_tra_phong_checkout` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class BienBanCheckoutSqlFields {
  static const id = 'id';
  static const cuDanId = 'cu_dan_id';
  static const chiSoDienCuoi = 'chi_so_dien_cuoi';
  static const chiSoNuocCuoi = 'chi_so_nuoc_cuoi';
  static const huHongThietHai = 'hu_hong_thiet_hai';
  static const chiPhiKhauTru = 'chi_phi_khau_tru';
  static const xacNhanHaiBen = 'xac_nhan_hai_ben';
  static const ngayCheckout = 'ngay_checkout';
}

/// 11. Schema trường bảng `nhat_ky_vi_pham_noi_quy` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class NhatKyViPhamSqlFields {
  static const id = 'id';
  static const cuDanId = 'cu_dan_id';
  static const noiDungViPham = 'noi_dung_vi_pham';
  static const mucPhat = 'muc_phat';
  static const ngayGhiNhan = 'ngay_ghi_nhan';
}

/// 12. Schema trường bảng `quyet_toan_chu_tro` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class QuyetToanChuTroSqlFields {
  static const id = 'id';
  static const chuTroId = 'chu_tro_id';
  static const tongTienGiaoDich = 'tong_tien_giao_dich';
  static const phiHoaHongHeThong = 'phi_hoa_hong_he_thong';
  static const soTienThucNhan = 'so_tien_thuc_nhan';
  static const trangThai = 'trang_thai';
  static const ngayQuyetToan = 'ngay_quyet_toan';
}

/// 13. Schema trường bảng `xac_thuc_cccd` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class XacThucCccdSqlFields {
  static const id = 'id';
  static const nguoiDungId = 'nguoi_dung_id';
  static const soCccd = 'so_cccd';
  static const hoTenCccd = 'ho_ten_cccd';
  static const ngaySinh = 'ngay_sinh';
  static const anhMatTruoc = 'anh_mat_truoc';
  static const anhMatSau = 'anh_mat_sau';
  static const trangThaiXacThuc = 'trang_thai_xac_thuc';
  static const ngayXacThuc = 'ngay_xac_thuc';
}

/// 14. Schema trường bảng `giao_dich_giu_coc` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class GiaoDichGiuCocSqlFields {
  static const id = 'id';
  static const donDatPhongId = 'don_dat_phong_id';
  static const soTien = 'so_tien';
  static const maGiaoDichQr = 'ma_giao_dich_qr';
  static const trangThai = 'trang_thai';
  static const ngayThanhToan = 'ngay_thanh_toan';
  static const ngayGiaiNgan = 'ngay_giai_ngan';
}

/// 15. Schema trường bảng `phuong_tien_cu_dan` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class PhuongTienCuDanSqlFields {
  static const id = 'id';
  static const cuDanId = 'cu_dan_id';
  static const loaiXe = 'loai_xe';
  static const bienSo = 'bien_so';
  static const mauXe = 'mau_xe';
}

/// 16. Schema trường bảng `bao_cao_vi_pham_bai_dang` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class BaoCaoViPhamSqlFields {
  static const id = 'id';
  static const baiDangId = 'bai_dang_id';
  static const nguoiBaoCaoId = 'nguoi_bao_cao_id';
  static const lyDo = 'ly_do';
  static const trangThai = 'trang_thai';
  static const ngayTao = 'ngay_tao';
}

/// 17. Schema trường bảng `phong_tro_yeu_thich` theo SQL_NHOM4_CHUYENDEDIDONG.sql
abstract final class PhongTroYeuThichSqlFields {
  static const id = 'id';
  static const nguoiDungId = 'nguoi_dung_id';
  static const phongTroId = 'phong_tro_id';
  static const ngayLuu = 'ngay_luu';
}

/// ĐỊNH NGHĨA CÁC TRƯỜNG DỮ LIỆU FIRESTORE CHUẨN TIẾNG ANH (SNAKE_CASE & CAMELCASE)
/// Cho role Host theo giao diện Firestore quốc tế (như hình):

/// English fields for Property documents
abstract final class PropertyDbFields {
  static const id = 'id';
  static const hostId = 'host_id';
  static const name = 'name';
  static const address = 'address';
  static const city = 'city';
  static const district = 'district';
  static const ward = 'ward';
  static const description = 'description';
  static const plannedRooms = 'planned_rooms';
  static const floors = 'floors';
  static const minRent = 'min_rent';
  static const maxRent = 'max_rent';
  static const images = 'images';
  static const status = 'status';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
}

/// English fields for Room documents
abstract final class RoomDbFields {
  static const id = 'id';
  static const propertyId = 'property_id';
  static const hostId = 'host_id';
  static const roomCode = 'room_code';
  static const title = 'title';
  static const description = 'description';
  static const area = 'area';
  static const rentalPrice = 'rental_price';
  static const depositAmount = 'deposit_amount';
  static const electricityRate = 'electricity_rate';
  static const waterRate = 'water_rate';
  static const wifiRate = 'wifi_rate';
  static const serviceFee = 'service_fee';
  static const floor = 'floor';
  static const capacity = 'capacity';
  static const roomType = 'room_type';
  static const status = 'status';
  static const isAvailable = 'is_available';
  static const amenities = 'amenities';
  static const images = 'images';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
}

/// English fields for Room Image documents
abstract final class RoomImageDbFields {
  static const id = 'id';
  static const roomId = 'room_id';
  static const url = 'url';
  static const isPrimary = 'is_primary';
  static const isCover = 'is_cover';
  static const sortOrder = 'sort_order';
  static const createdAt = 'created_at';
}

/// English fields for Room Amenity documents (N-N junction)
abstract final class RoomAmenityDbFields {
  static const id = 'id';
  static const roomId = 'room_id';
  static const amenityId = 'amenity_id';
  static const amenityName = 'amenity_name';
  static const inUse = 'in_use';
  static const createdAt = 'created_at';
}

/// English fields for Rental Post documents
abstract final class RentalPostDbFields {
  static const id = 'id';
  static const roomId = 'room_id';
  static const hostId = 'host_id';
  static const title = 'title';
  static const description = 'description';
  static const rentalPrice = 'rental_price';
  static const depositAmount = 'deposit_amount';
  static const isPinned = 'is_pinned';
  static const status = 'status';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
}

/// English fields for Post Report documents
abstract final class PostReportDbFields {
  static const id = 'id';
  static const postId = 'post_id';
  static const reporterId = 'reporter_id';
  static const reason = 'reason';
  static const status = 'status';
  static const createdAt = 'created_at';
}

/// English fields for Booking documents
abstract final class BookingDbFields {
  static const id = 'id';
  static const roomId = 'room_id';
  static const hostId = 'host_id';
  static const hostName = 'host_name';
  static const renterId = 'renter_id';
  static const renterName = 'renter_name';
  static const renterPhone = 'renter_phone';
  static const renterGender = 'renter_gender';
  static const roomTitle = 'room_title';
  static const roomAddress = 'room_address';
  static const roomPrice = 'room_price';
  static const depositAmount = 'deposit_amount';
  static const totalAmount = 'total_amount';
  static const rentalMonths = 'rental_months';
  static const expectedMoveInDate = 'expected_move_in_date';
  static const acceptedDate = 'accepted_date';
  static const status = 'status';
  static const note = 'note';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
}

/// English fields for Escrow Deposit documents (1-1 with booking)
abstract final class EscrowDepositDbFields {
  static const id = 'id';
  static const bookingId = 'booking_id';
  static const amount = 'amount';
  static const qrTransactionCode = 'qr_transaction_code';
  static const status = 'status';
  static const paidAt = 'paid_at';
  static const disbursedAt = 'disbursed_at';
  static const createdAt = 'created_at';
}

/// English fields for Checkin Record documents (1-1 with booking)
abstract final class CheckinRecordDbFields {
  static const id = 'id';
  static const bookingId = 'booking_id';
  static const periodId = 'period_id';
  static const scannerId = 'scanner_id';
  static const initialElectricityMeter = 'initial_electricity_meter';
  static const initialWaterMeter = 'initial_water_meter';
  static const electricityRate = 'electricity_rate';
  static const waterRate = 'water_rate';
  static const facilityCondition = 'facility_condition';
  static const checkinQrCode = 'checkin_qr_code';
  static const renterConfirmed = 'renter_confirmed';
  static const isKeyHandedOver = 'is_key_handed_over';
  static const checkinDate = 'checkin_date';
  static const note = 'note';
  static const status = 'status';
  static const createdAt = 'created_at';
}

/// English fields for Resident documents (1-N with room)
abstract final class ResidentDbFields {
  static const id = 'id';
  static const roomId = 'room_id';
  static const userId = 'user_id';
  static const periodId = 'period_id';
  static const fullName = 'full_name';
  static const phoneNumber = 'phone_number';
  static const avatar = 'avatar';
  static const roommateRequestId = 'roommate_request_id';
  static const formId = 'form_id';
  static const startDate = 'start_date';
  static const endDate = 'end_date';
  static const status = 'status';
  static const createdAt = 'created_at';
}

/// English fields for Resident Vehicle documents (1-N with resident)
abstract final class ResidentVehicleDbFields {
  static const id = 'id';
  static const residentId = 'resident_id';
  static const vehicleType = 'vehicle_type';
  static const licensePlate = 'license_plate';
  static const color = 'color';
  static const createdAt = 'created_at';
}

/// English fields for Checkout Record documents (1-1 with resident)
abstract final class CheckoutRecordDbFields {
  static const id = 'id';
  static const residentId = 'resident_id';
  static const roomId = 'room_id';
  static const renterId = 'renter_id';
  static const periodId = 'period_id';
  static const finalElectricityMeter = 'final_electricity_meter';
  static const finalWaterMeter = 'final_water_meter';
  static const damagesDescription = 'damages_description';
  static const deductionAmount = 'deduction_amount';
  static const refundAmount = 'refund_amount';
  static const depositAmount = 'deposit_amount';
  static const bothConfirmed = 'both_confirmed';
  static const checkoutDate = 'checkout_date';
  static const status = 'status';
  static const note = 'note';
  static const createdAt = 'created_at';
}

/// English fields for Violation Record documents (1-N with resident)
abstract final class ViolationRecordDbFields {
  static const id = 'id';
  static const residentId = 'resident_id';
  static const landlordId = 'landlord_id';
  static const roomId = 'room_id';
  static const roomCode = 'room_code';
  static const propertyName = 'property_name';
  static const periodId = 'period_id';
  static const tenantId = 'tenant_id';
  static const tenantName = 'tenant_name';
  static const tenantPhone = 'tenant_phone';
  static const violationIds = 'violation_ids';
  static const violationTitles = 'violation_titles';
  static const violationContent = 'violation_content';
  static const fineAmount = 'fine_amount';
  static const paymentMethod = 'payment_method';
  static const status = 'status';
  static const description = 'description';
  static const evidenceUrls = 'evidence_urls';
  static const lastReminderAt = 'last_reminder_at';
  static const paidAt = 'paid_at';
  static const paidMethod = 'paid_method';
  static const paidCollector = 'paid_collector';
  static const recordedAt = 'recorded_at';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
}

/// English fields for Host Settlement documents (1-N with host)
abstract final class HostSettlementDbFields {
  static const id = 'id';
  static const hostId = 'host_id';
  static const totalTransactionAmount = 'total_transaction_amount';
  static const systemCommissionFee = 'system_commission_fee';
  static const netPayoutAmount = 'net_payout_amount';
  static const status = 'status';
  static const settledAt = 'settled_at';
  static const createdAt = 'created_at';
}

/// English fields for ID Verification documents (1-1 with host)
abstract final class IdVerificationDbFields {
  static const id = 'id';
  static const userId = 'user_id';
  static const idNumber = 'id_number';
  static const fullName = 'full_name';
  static const dateOfBirth = 'date_of_birth';
  static const frontImageUrl = 'front_image_url';
  static const backImageUrl = 'back_image_url';
  static const verificationStatus = 'verification_status';
  static const verifiedAt = 'verified_at';
  static const createdAt = 'created_at';
}

/// English fields for Favorite Room documents (N-N junction)
abstract final class FavoriteRoomDbFields {
  static const id = 'id';
  static const userId = 'user_id';
  static const roomId = 'room_id';
  static const savedAt = 'saved_at';
  static const createdAt = 'created_at';
}

/// ĐỊNH NGHĨA ÁNH XẠ FIRESTORE CHUẨN TIẾNG ANH 100% CHO ROLE HOST (CHỦ TRỌ)
/// - Mối quan hệ 1-1 và 1-N: Ánh xạ dạng SUB-COLLECTION dưới document cha
/// - Mối quan hệ N-N: Ánh xạ dạng COLLECTION RIÊNG (Root Collection) làm bảng trung gian
abstract final class HostFirestorePaths {
  // ==========================================
  // 1. CÁC QUAN HỆ 1-1 VÀ 1-N (SUB-COLLECTIONS) - CHUẨN TIẾNG ANH
  // ==========================================

  /// [1-1] ID Verification: Sub-collection of users
  /// Path: users/{hostId}/id_verifications/{verificationId}
  static String idVerifications(String hostId) => 'users/$hostId/id_verifications';
  static String idVerificationDoc(String hostId, String verificationId) =>
      'users/$hostId/id_verifications/$verificationId';

  /// [1-N] Properties: Sub-collection of users (host)
  /// Path: users/{hostId}/properties/{propertyId}
  static String properties(String hostId) => 'users/$hostId/properties';
  static String propertyDoc(String hostId, String propertyId) =>
      'users/$hostId/properties/$propertyId';

  /// [1-N] Rooms: Sub-collection of properties
  /// Path: properties/{propertyId}/rooms/{roomId}
  static String rooms(String propertyId) => 'properties/$propertyId/rooms';
  static String roomDoc(String propertyId, String roomId) =>
      'properties/$propertyId/rooms/$roomId';

  /// [1-N] Nested Rooms: users/{hostId}/properties/{propertyId}/rooms/{roomId}
  static String nestedRooms(String hostId, String propertyId) =>
      'users/$hostId/properties/$propertyId/rooms';

  /// [1-N] Room Images: Sub-collection of rooms
  /// Path: rooms/{roomId}/room_images/{imageId}
  static String roomImages(String roomId) => 'rooms/$roomId/room_images';
  static String roomImageDoc(String roomId, String imageId) =>
      'rooms/$roomId/room_images/$imageId';

  /// [1-N] Rental Posts: Sub-collection of rooms
  /// Path: rooms/{roomId}/rental_posts/{postId}
  static String rentalPosts(String roomId) => 'rooms/$roomId/rental_posts';
  static String rentalPostDoc(String roomId, String postId) =>
      'rooms/$roomId/rental_posts/$postId';

  /// [1-N] Post Reports: Sub-collection of rental_posts
  /// Path: rental_posts/{postId}/post_reports/{reportId}
  static String postReports(String postId) => 'rental_posts/$postId/post_reports';
  static String postReportDoc(String postId, String reportId) =>
      'rental_posts/$postId/post_reports/$reportId';

  /// [1-N] Bookings: Sub-collection of rooms
  /// Path: rooms/{roomId}/bookings/{bookingId}
  static String bookings(String roomId) => 'rooms/$roomId/bookings';
  static String bookingDoc(String roomId, String bookingId) =>
      'rooms/$roomId/bookings/$bookingId';

  /// [1-1] Escrow Deposits: Sub-collection of bookings
  /// Path: bookings/{bookingId}/escrow_deposits/{depositId}
  static String escrowDeposits(String bookingId) => 'bookings/$bookingId/escrow_deposits';
  static String escrowDepositDoc(String bookingId, String depositId) =>
      'bookings/$bookingId/escrow_deposits/$depositId';

  /// [1-1] Checkin Records: Sub-collection of bookings
  /// Path: bookings/{bookingId}/checkin_records/{checkinId}
  static String checkinRecords(String bookingId) => 'bookings/$bookingId/checkin_records';
  static String checkinRecordDoc(String bookingId, String checkinId) =>
      'bookings/$bookingId/checkin_records/$checkinId';

  /// [1-N] Residents: Sub-collection of rooms
  /// Path: rooms/{roomId}/residents/{residentId}
  static String residents(String roomId) => 'rooms/$roomId/residents';
  static String residentDoc(String roomId, String residentId) =>
      'rooms/$roomId/residents/$residentId';

  /// [1-N] Resident Vehicles: Sub-collection of residents
  /// Path: residents/{residentId}/resident_vehicles/{vehicleId}
  static String residentVehicles(String residentId) =>
      'residents/$residentId/resident_vehicles';
  static String residentVehicleDoc(String residentId, String vehicleId) =>
      'residents/$residentId/resident_vehicles/$vehicleId';

  /// [1-1] Checkout Records: Sub-collection of residents
  /// Path: residents/{residentId}/checkout_records/{checkoutId}
  static String checkoutRecords(String residentId) =>
      'residents/$residentId/checkout_records';
  static String checkoutRecordDoc(String residentId, String checkoutId) =>
      'residents/$residentId/checkout_records/$checkoutId';

  /// [1-N] Violation Records: Sub-collection of residents
  /// Path: residents/{residentId}/violation_records/{violationId}
  static String violationRecords(String residentId) =>
      'residents/$residentId/violation_records';
  static String violationRecordDoc(String residentId, String violationId) =>
      'residents/$residentId/violation_records/$violationId';

  /// [1-N] Host Settlements: Sub-collection of users (host)
  /// Path: users/{hostId}/host_settlements/{settlementId}
  static String hostSettlements(String hostId) => 'users/$hostId/host_settlements';
  static String hostSettlementDoc(String hostId, String settlementId) =>
      'users/$hostId/host_settlements/$settlementId';

  // ==========================================
  // 2. CÁC QUAN HỆ N-N (COLLECTIONS RIÊNG BIỆT) - CHUẨN TIẾNG ANH
  // ==========================================

  /// [N-N] Room Amenities: Junction collection between rooms and amenities
  /// Path: room_amenities/{roomId_amenityId}
  static const roomAmenities = 'room_amenities';
  static String roomAmenityDoc(String id) => '$roomAmenities/$id';
  static String roomAmenityCompositeId(String roomId, String amenityId) =>
      '${roomId}_$amenityId';

  /// [N-N] Favorite Rooms: Junction collection between users and rooms
  /// Path: favorite_rooms/{userId_roomId}
  static const favoriteRooms = 'favorite_rooms';
  static String favoriteRoomDoc(String id) => '$favoriteRooms/$id';
  static String favoriteRoomCompositeId(String userId, String roomId) =>
      '${userId}_$roomId';

  /// [Catalog] Amenities catalog
  static const amenities = 'amenities';
  static String amenityDoc(String amenityId) => '$amenities/$amenityId';

  // ==========================================
  // 3. VIETNAMESE ALIASES (FORWARD ĐẾN PHƯƠNG THỨC TIẾNG ANH)
  // ==========================================
  static String xacThucCccd(String chuTroId) => idVerifications(chuTroId);
  static String xacThucCccdDoc(String chuTroId, String cccdId) =>
      idVerificationDoc(chuTroId, cccdId);
  static String batDongSan(String chuTroId) => properties(chuTroId);
  static String batDongSanDoc(String chuTroId, String batDongSanId) =>
      propertyDoc(chuTroId, batDongSanId);
  static String phongTro(String batDongSanId) => rooms(batDongSanId);
  static String phongTroDoc(String batDongSanId, String phongTroId) =>
      roomDoc(batDongSanId, phongTroId);
  static String nestedPhongTro(String chuTroId, String batDongSanId) =>
      nestedRooms(chuTroId, batDongSanId);
  static String hinhAnhPhong(String phongTroId) => roomImages(phongTroId);
  static String hinhAnhPhongDoc(String phongTroId, String hinhAnhId) =>
      roomImageDoc(phongTroId, hinhAnhId);
  static String baiDangChoThue(String phongTroId) => rentalPosts(phongTroId);
  static String baiDangChoThueDoc(String phongTroId, String baiDangId) =>
      rentalPostDoc(phongTroId, baiDangId);
  static String baoCaoViPham(String baiDangId) => postReports(baiDangId);
  static String baoCaoViPhamDoc(String baiDangId, String baoCaoId) =>
      postReportDoc(baiDangId, baoCaoId);
  static String donDatPhong(String phongTroId) => bookings(phongTroId);
  static String donDatPhongDoc(String phongTroId, String donDatPhongId) =>
      bookingDoc(phongTroId, donDatPhongId);
  static String giaoDichGiuCoc(String donDatPhongId) => escrowDeposits(donDatPhongId);
  static String giaoDichGiuCocDoc(String donDatPhongId, String giaoDichId) =>
      escrowDepositDoc(donDatPhongId, giaoDichId);
  static String bienBanCheckin(String donDatPhongId) => checkinRecords(donDatPhongId);
  static String bienBanCheckinDoc(String donDatPhongId, String checkinId) =>
      checkinRecordDoc(donDatPhongId, checkinId);
  static String cuDanDangO(String phongTroId) => residents(phongTroId);
  static String cuDanDangODoc(String phongTroId, String cuDanId) =>
      residentDoc(phongTroId, cuDanId);
  static String phuongTienCuDan(String cuDanId) => residentVehicles(cuDanId);
  static String phuongTienCuDanDoc(String cuDanId, String phuongTienId) =>
      residentVehicleDoc(cuDanId, phuongTienId);
  static String bienBanCheckout(String cuDanId) => checkoutRecords(cuDanId);
  static String bienBanCheckoutDoc(String cuDanId, String checkoutId) =>
      checkoutRecordDoc(cuDanId, checkoutId);
  static String nhatKyViPham(String cuDanId) => violationRecords(cuDanId);
  static String nhatKyViPhamDoc(String cuDanId, String viPhamId) =>
      violationRecordDoc(cuDanId, viPhamId);
  static String quyetToanChuTro(String chuTroId) => hostSettlements(chuTroId);
  static String quyetToanChuTroDoc(String chuTroId, String quyetToanId) =>
      hostSettlementDoc(chuTroId, quyetToanId);
  static const tienIchPhongTro = roomAmenities;
  static String tienIchPhongTroDoc(String id) => roomAmenityDoc(id);
  static String tienIchPhongTroCompositeId(String phongTroId, String tienIchId) =>
      roomAmenityCompositeId(phongTroId, tienIchId);
  static const phongTroYeuThich = favoriteRooms;
  static String phongTroYeuThichDoc(String id) => favoriteRoomDoc(id);
  static String phongTroYeuThichCompositeId(String nguoiDungId, String phongTroId) =>
      favoriteRoomCompositeId(nguoiDungId, phongTroId);
  static const danhMucTienIch = amenities;
  static String danhMucTienIchDoc(String tienIchId) => amenityDoc(tienIchId);
}




