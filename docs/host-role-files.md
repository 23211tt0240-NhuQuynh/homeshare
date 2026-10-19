# Danh mục mã nguồn chức năng Chủ trọ

Đường dẫn gốc: `D:\CDDD2\homeshare-dev-THE`.

Đã quét 178 tệp Dart/JavaScript trong lib, test và functions để lập chỉ mục import và khai báo lớp. Module riêng của Chủ trọ có 57 tệp. Danh mục này phân loại phạm vi mã nguồn, không phải kết quả kiểm thử hay xác nhận mọi chức năng đã hoàn thiện.

## Màn hình và điều hướng

- [host_checkin_checkout_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/screens/host_checkin_checkout_screen.dart) — HostCheckinCheckoutScreen, _HostCheckinCheckoutScreenState
- [host_checkin_handover_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/screens/host_checkin_handover_screen.dart) — HostCheckinHandoverScreen, _HostCheckinHandoverScreenState
- [host_create_post_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/screens/host_create_post_screen.dart) — HostCreatePostScreen, _HostCreatePostScreenState
- [host_create_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/screens/host_create_screen.dart) — HostCreateScreen, _HostCreateScreenState
- [host_create_violation_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/screens/host_create_violation_screen.dart) — HostCreateViolationScreen, _HostCreateViolationScreenState
- [host_dashboard_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/screens/host_dashboard_screen.dart) — HostDashboardScreen, _HostDashboardScreenState
- [host_main_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/screens/host_main_screen.dart) — HostMainScreen, _HostMainScreenState, _HostPlaceholderScreen
- [host_management_menu.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/screens/host_management_menu.dart) — HostManagementSection, HostManagementMenu
- [host_property_management_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/screens/host_property_management_screen.dart) — _PropertyAction, HostPropertyManagementScreen
- [host_room_detail_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/screens/host_room_detail_screen.dart) — HostRoomDetailScreen, _HostRoomDetailScreenState
- [host_room_edit_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/screens/host_room_edit_screen.dart) — HostRoomEditScreen, _HostRoomEditScreenState
- [host_room_list_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/screens/host_room_list_screen.dart) — HostRoomListScreen, _HostRoomListScreenState
- [host_tenant_management_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/screens/host_tenant_management_screen.dart) — HostTenantManagementScreen, _HostTenantManagementScreenState
- [host_violation_management_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/screens/host_violation_management_screen.dart) — HostViolationManagementScreen, _HostViolationManagementScreenState

## State và provider

- [checkin_checkout_provider.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/providers/checkin_checkout_provider.dart) — 
- [handover_provider.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/providers/handover_provider.dart) — HandoverParams
- [host_amenity_provider.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/providers/host_amenity_provider.dart) — 
- [host_dashboard_provider.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/providers/host_dashboard_provider.dart) — HostDashboardFilterOptions, HostDashboardFilter
- [host_home_provider.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/providers/host_home_provider.dart) — HostHomeSort, HostPriceSort, HostHomeFilterState, HostHomeFilterNotifier
- [host_location_provider.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/providers/host_location_provider.dart) — HostLocationSearchNotifier
- [host_management_provider.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/providers/host_management_provider.dart) — HostUpload, HostRepository
- [tenant_management_provider.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/providers/tenant_management_provider.dart) — 
- [violation_form_provider.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/providers/violation_form_provider.dart) — ViolationFormState, ViolationFormNotifier
- [violation_provider.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/providers/violation_provider.dart) — HostViolationMonthFilterNotifier, HostViolationStatusFilterNotifier

## Dữ liệu cơ sở và bài đăng

- [host_post_repository.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/data/host_post_repository.dart) — HostPostRepository
- [host_property.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/data/host_property.dart) — HostProperty, PropertySummary

## Truy xuất dữ liệu nghiệp vụ

- [checkin_checkout_repository.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/repositories/checkin_checkout_repository.dart) — CheckinCheckoutItem, CheckinCheckoutRepository
- [handover_repository.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/repositories/handover_repository.dart) — HandoverRoomContext, HandoverRepository
- [tenant_repository.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/repositories/tenant_repository.dart) — TenantItem, TenantStats, TenantRepository
- [violation_repository.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/repositories/violation_repository.dart) — HostOccupiedRoomItem, ViolationMonthlyStats, ViolationRepository

## Model vi phạm và hóa đơn

- [invoice_line_model.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/models/invoice_line_model.dart) — InvoiceLineModel
- [violation_model.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/models/violation_model.dart) — ViolationModel
- [violation_record_model.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/models/violation_record_model.dart) — ViolationRecordModel

## Thành phần giao diện

- [checkin_checkout_card.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/checkin_checkout_card.dart) — CheckinCheckoutCard
- [evidence_picker.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/evidence_picker.dart) — EvidencePicker
- [handover_item_card.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/handover_item_card.dart) — HandoverItemCard
- [handover_meter_card.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/handover_meter_card.dart) — HandoverMeterCard
- [host_checkin_qr_result_sheet.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/host_checkin_qr_result_sheet.dart) — HostCheckinQrResultSheet, _HostCheckinQrResultSheetState
- [host_deposit_input.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/host_deposit_input.dart) — HostDepositInput
- [host_form_theme.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/host_form_theme.dart) — HostTheme, HostImageUtils, HostCardSection, HostSectionTitle, HostAddImageButton, HostImageThumbnail, HostAmenityTile
- [host_post_card.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/host_post_card.dart) — HostPostCard
- [host_qr_scanner_modal.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/host_qr_scanner_modal.dart) — HostQrScannerModal, _HostQrScannerModalState, _ScannerCornerPainter
- [host_range_input.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/host_range_input.dart) — HostRangeInput, _HostRangeInputState
- [host_room_widgets.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/host_room_widgets.dart) — HostRoomSection, HostRoomBadge, HostRoomTenant
- [payment_action_sheet.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/payment_action_sheet.dart) — PaymentActionSheet
- [tenant_card.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/tenant_card.dart) — TenantCard
- [violation_record_card.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/violation_record_card.dart) — ViolationRecordCard, _ViolationRecordCardState
- [violation_summary_card.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/violation_summary_card.dart) — ViolationSummaryCard
- [violation_type_selector.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/widgets/violation_type_selector.dart) — ViolationTypeSelector

## Thông báo và xử lý yêu cầu

- [host_notification_model.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/notifications/models/host_notification_model.dart) — HostNotificationModel
- [notification_types.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/notifications/notification_types.dart) — HostNotificationType
- [host_notification_provider.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/notifications/providers/host_notification_provider.dart) — HostNotificationSearchQueryNotifier, SelectedHostNotificationTypeNotifier
- [host_notification_repository.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/notifications/repositories/host_notification_repository.dart) — HostNotificationRepository
- [host_booking_change_confirmation_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/notifications/screens/host_booking_change_confirmation_screen.dart) — HostBookingChangeConfirmationScreen, _HostBookingChangeConfirmationScreenState
- [host_notifications_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/notifications/screens/host_notifications_screen.dart) — HostNotificationsScreen, _HostNotificationsScreenState
- [host_update_deposit_bottom_sheet.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/notifications/widgets/host_update_deposit_bottom_sheet.dart) — HostUpdateDepositBottomSheet, _HostUpdateDepositBottomSheetState
- [notification_card.dart](D:/CDDD2/homeshare-dev-THE/lib/features/host/notifications/widgets/notification_card.dart) — NotificationCard

## Các phụ thuộc dùng chung được module Chủ trọ import trực tiếp

- [lib/core/constants/app_colors.dart](D:/CDDD2/homeshare-dev-THE/lib/core/constants/app_colors.dart)
- [lib/core/constants/firestore_collections.dart](D:/CDDD2/homeshare-dev-THE/lib/core/constants/firestore_collections.dart)
- [lib/core/constants/vietnam_locations.dart](D:/CDDD2/homeshare-dev-THE/lib/core/constants/vietnam_locations.dart)
- [lib/core/services/booking_service.dart](D:/CDDD2/homeshare-dev-THE/lib/core/services/booking_service.dart)
- [lib/core/utils/id_generator.dart](D:/CDDD2/homeshare-dev-THE/lib/core/utils/id_generator.dart)
- [lib/core/utils/room_amenities.dart](D:/CDDD2/homeshare-dev-THE/lib/core/utils/room_amenities.dart)
- [lib/core/utils/room_deposit.dart](D:/CDDD2/homeshare-dev-THE/lib/core/utils/room_deposit.dart)
- [lib/core/utils/room_identity.dart](D:/CDDD2/homeshare-dev-THE/lib/core/utils/room_identity.dart)
- [lib/core/utils/vietnamese_utils.dart](D:/CDDD2/homeshare-dev-THE/lib/core/utils/vietnamese_utils.dart)
- [lib/core/utils/vnd_input.dart](D:/CDDD2/homeshare-dev-THE/lib/core/utils/vnd_input.dart)
- [lib/data/models/booking_model.dart](D:/CDDD2/homeshare-dev-THE/lib/data/models/booking_model.dart)
- [lib/data/models/checkin_model.dart](D:/CDDD2/homeshare-dev-THE/lib/data/models/checkin_model.dart)
- [lib/data/models/checkout_record_model.dart](D:/CDDD2/homeshare-dev-THE/lib/data/models/checkout_record_model.dart)
- [lib/data/models/handover_item_model.dart](D:/CDDD2/homeshare-dev-THE/lib/data/models/handover_item_model.dart)
- [lib/data/models/host_post_model.dart](D:/CDDD2/homeshare-dev-THE/lib/data/models/host_post_model.dart)
- [lib/data/models/period_model.dart](D:/CDDD2/homeshare-dev-THE/lib/data/models/period_model.dart)
- [lib/data/models/resident_model.dart](D:/CDDD2/homeshare-dev-THE/lib/data/models/resident_model.dart)
- [lib/data/models/room_model.dart](D:/CDDD2/homeshare-dev-THE/lib/data/models/room_model.dart)
- [lib/data/models/roommate_post_model.dart](D:/CDDD2/homeshare-dev-THE/lib/data/models/roommate_post_model.dart)
- [lib/features/auth/providers/auth_provider.dart](D:/CDDD2/homeshare-dev-THE/lib/features/auth/providers/auth_provider.dart)
- [lib/features/auth/providers/user_provider.dart](D:/CDDD2/homeshare-dev-THE/lib/features/auth/providers/user_provider.dart)
- [lib/features/chat/screens/chat_detail_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/chat/screens/chat_detail_screen.dart)
- [lib/features/chat/screens/chat_list_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/chat/screens/chat_list_screen.dart)
- [lib/features/home/screens/home_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/home/screens/home_screen.dart)

## Điểm tích hợp ngoài module Chủ trọ

- [lib/main.dart](D:/CDDD2/homeshare-dev-THE/lib/main.dart) — Khởi động và điều hướng vào HostMainScreen theo vai trò.
- [lib/features/auth/services/role_resolver.dart](D:/CDDD2/homeshare-dev-THE/lib/features/auth/services/role_resolver.dart) — Chuẩn hóa vai trò renter, host, admin.
- [lib/features/auth/screens/register_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/auth/screens/register_screen.dart) — Đăng ký và lựa chọn vai trò.
- [lib/features/profile/screens/account_settings_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/profile/screens/account_settings_screen.dart) — Cài đặt tài khoản và chuyển vai trò.
- [lib/features/profile/screens/personal_profile_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/profile/screens/personal_profile_screen.dart) — Thông tin cá nhân dùng chung.
- [lib/features/profile/screens/cccd_verification_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/profile/screens/cccd_verification_screen.dart) — Xác thực CCCD dùng chung.
- [lib/core/services/booking_service.dart](D:/CDDD2/homeshare-dev-THE/lib/core/services/booking_service.dart) — Duyệt, nhận phòng, hủy và theo dõi đơn thuê.
- [lib/core/services/room_service.dart](D:/CDDD2/homeshare-dev-THE/lib/core/services/room_service.dart) — Đưa dữ liệu phòng và bài đăng ra bảng tin công khai.
- [lib/core/services/chat_service.dart](D:/CDDD2/homeshare-dev-THE/lib/core/services/chat_service.dart) — Chat và thông báo lời mời ở ghép, thông báo cho chủ trọ.
- [lib/core/services/call_service.dart](D:/CDDD2/homeshare-dev-THE/lib/core/services/call_service.dart) — Cuộc gọi dùng chung.
- [lib/core/services/call_push_service.dart](D:/CDDD2/homeshare-dev-THE/lib/core/services/call_push_service.dart) — Thông báo cuộc gọi dùng chung.
- [lib/core/services/image_storage_service.dart](D:/CDDD2/homeshare-dev-THE/lib/core/services/image_storage_service.dart) — Dịch vụ ảnh dùng chung; module host cũng có logic upload riêng.
- [lib/features/renter/screens/user_notifications_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/renter/screens/user_notifications_screen.dart) — Phía người thuê xử lý lời mời ở ghép có liên quan đến chủ trọ.
- [lib/features/admin/services/admin_service.dart](D:/CDDD2/homeshare-dev-THE/lib/features/admin/services/admin_service.dart) — Phía Admin duyệt bài và giải ngân liên quan đến chủ trọ.
- [lib/features/admin/screens/settlement_invoice_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/admin/screens/settlement_invoice_screen.dart) — Màn hình quyết toán phía Admin, không thuộc giao diện role Host.
- [lib/features/admin/screens/settlement_receipt_screen.dart](D:/CDDD2/homeshare-dev-THE/lib/features/admin/screens/settlement_receipt_screen.dart) — Biên nhận phía Admin, không thuộc giao diện role Host.
- [functions/index.js](D:/CDDD2/homeshare-dev-THE/functions/index.js) — Backend token Agora và thông báo cuộc gọi cho các vai trò.

## Kiểm thử liên quan trực tiếp

- [firestore_collection_separation_test.dart](D:/CDDD2/homeshare-dev-THE/test/firestore_collection_separation_test.dart)
- [host_create_post_test.dart](D:/CDDD2/homeshare-dev-THE/test/host_create_post_test.dart)
- [host_dashboard_test.dart](D:/CDDD2/homeshare-dev-THE/test/host_dashboard_test.dart)
- [host_management_screens_test.dart](D:/CDDD2/homeshare-dev-THE/test/host_management_screens_test.dart)
- [host_management_test.dart](D:/CDDD2/homeshare-dev-THE/test/host_management_test.dart)
- [host_notifications_test.dart](D:/CDDD2/homeshare-dev-THE/test/host_notifications_test.dart)
- [host_range_input_test.dart](D:/CDDD2/homeshare-dev-THE/test/host_range_input_test.dart)
- [host_room_management_test.dart](D:/CDDD2/homeshare-dev-THE/test/host_room_management_test.dart)
- [host_violation_test.dart](D:/CDDD2/homeshare-dev-THE/test/host_violation_test.dart)
- [post_visibility_test.dart](D:/CDDD2/homeshare-dev-THE/test/post_visibility_test.dart)
- [role_routing_test.dart](D:/CDDD2/homeshare-dev-THE/test/role_routing_test.dart)
- [roommate_approval_and_checkin_qr_test.dart](D:/CDDD2/homeshare-dev-THE/test/roommate_approval_and_checkin_qr_test.dart)
- [roommate_invitation_flow_test.dart](D:/CDDD2/homeshare-dev-THE/test/roommate_invitation_flow_test.dart)
- [violation_models_test.dart](D:/CDDD2/homeshare-dev-THE/test/violation_models_test.dart)

## Cấu hình và tài liệu Firebase liên quan

- [firebase.json](D:/CDDD2/homeshare-dev-THE/firebase.json)
- [storage.rules](D:/CDDD2/homeshare-dev-THE/storage.rules)
- [docs/firebase/host-management-setup.md](D:/CDDD2/homeshare-dev-THE/docs/firebase/host-management-setup.md)
- [docs/firebase/host-room-management.md](D:/CDDD2/homeshare-dev-THE/docs/firebase/host-room-management.md)
- [docs/firebase/firestore-host.rules.snippet](D:/CDDD2/homeshare-dev-THE/docs/firebase/firestore-host.rules.snippet)
- [docs/firebase/storage-host.rules.snippet](D:/CDDD2/homeshare-dev-THE/docs/firebase/storage-host.rules.snippet)
- [docs/firebase/firestore-team.draft.rules](D:/CDDD2/homeshare-dev-THE/docs/firebase/firestore-team.draft.rules)
- [docs/firebase/team-rules-guide.md](D:/CDDD2/homeshare-dev-THE/docs/firebase/team-rules-guide.md)
- [SQL_NHOM4_CHUYENDEDIDONG.sql](D:/CDDD2/homeshare-dev-THE/SQL_NHOM4_CHUYENDEDIDONG.sql)

## Lưu ý khi chỉnh sửa

- HostMainScreen là điểm vào; tab Tin nhắn dùng ChatListScreen và tab Cá nhân dùng HomeScreen.
- Tab QL Tiền tệ trong HostMainScreen hiện dùng _HostPlaceholderScreen. Các màn settlement trong features/admin thuộc role Admin.
- Không chỉ dựa vào tên file có chữ host: tenant_repository, handover_repository, checkin_checkout_repository và violation_repository đều là nghiệp vụ chủ trọ.
- Model dùng chung nằm ngoài features/host, bao gồm host_post_model, room_model, booking_model, period_model, resident_model, checkin_model, checkout_record_model, handover_item_model.
- Cần kiểm tra dữ liệu mẫu/fallback và tương thích schema cũ khi thay đổi nghiệp vụ.
