/// Tên collection Firestore dùng chung trong ứng dụng.
///
/// `rooms` là dữ liệu công khai cho luồng khách thuê. Kho phòng vận hành của
/// chủ trọ phải dùng `host_rooms` để hai vai trò không ghi chung một nơi.
abstract final class FirestoreCollections {
  static const publicRooms = 'rooms';
  static const hostRooms = 'host_rooms';
  static const hostProperties = 'properties';
  static const bookings = 'bookings';
  static const periods = 'periods';
  static const kyO = 'periods';
  static const checkins = 'checkins';
  static const residents = 'residents';
  static const handoverItems = 'handover_items';
  static const checkoutRecords = 'checkout_records';
  static const users = 'users';
  static const violations = 'violations';
  static const violationRecords = 'violation_records';
  static const invoiceLines = 'invoice_lines';
}
