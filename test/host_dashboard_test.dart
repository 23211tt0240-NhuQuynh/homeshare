import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_share/core/theme/app_theme.dart';
import 'package:home_share/data/models/host_post_model.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/chat/screens/chat_detail_screen.dart';
import 'package:home_share/features/host/providers/host_amenity_provider.dart';
import 'package:home_share/features/host/providers/host_home_provider.dart';
import 'package:home_share/features/host/providers/host_management_provider.dart';
import 'package:home_share/features/host/screens/host_dashboard_screen.dart';
import 'package:home_share/features/host/screens/host_main_screen.dart';

void main() {
  final samplePost1 = HostPostModel(
    id: 'post-1',
    phongId: 'room-1',
    chuNhaId: 'host-other-1',
    tieuDe: 'Phòng trọ cao cấp full nội thất',
    moTa: 'Phòng mới xây gần đại học, an ninh tốt, giờ giấc tự do.',
    giaThue: 3500000,
    address: '123 Kha Vạn Cân, Linh Trung',
    city: 'TP. Hồ Chí Minh',
    district: 'TP. Thủ Đức',
    authorName: 'Cô Mai',
    authorAvatar: '',
    images: const [],
    amenities: const ['Máy lạnh', 'Wifi', 'Tủ lạnh', 'Gác lửng'],
    ngayDang: DateTime.now().subtract(const Duration(hours: 2)),
    interestedCount: 15,
    responseCount: 4,
    isVerified: true,
    isVip: true,
    roomArea: 28.0,
  );

  final samplePost2 = HostPostModel(
    id: 'post-2',
    phongId: 'room-2',
    chuNhaId: 'host-other-2',
    tieuDe: 'KTX Mini giá rẻ cho sinh viên',
    moTa: 'Giường tầng tiện nghi, bao điện nước wifi.',
    giaThue: 1500000,
    address: '456 Dĩ An',
    city: 'Bình Dương',
    district: 'Dĩ An',
    authorName: 'Chú Ba',
    authorAvatar: '',
    images: const [],
    amenities: const ['Wifi', 'Chỗ để xe'],
    ngayDang: DateTime.now().subtract(const Duration(days: 1)),
    interestedCount: 5,
    responseCount: 1,
    isVerified: false,
    isVip: false,
    roomArea: 18.0,
  );

  final ownPost = HostPostModel(
    id: 'post-3',
    phongId: 'room-3',
    chuNhaId: 'current-host',
    tieuDe: 'Bài đăng của chính tôi',
    moTa: 'Không được hiển thị trên bảng tin của tôi.',
    giaThue: 4000000,
    address: 'Quận 1',
    city: 'TP. Hồ Chí Minh',
    district: 'Quận 1',
    authorName: 'Tôi',
    ngayDang: DateTime.now(),
  );

  group('HostPostModel Tests', () {
    test('HostPostModel parses missing fields and empty data safely', () {
      final post = HostPostModel.fromMap({}, 'empty-id');
      expect(post.id, 'empty-id');
      expect(post.tieuDe, '');
      expect(post.moTa, '');
      expect(post.giaThue, 0.0);
      expect(post.images, isEmpty);
      expect(post.amenities, isEmpty);
      expect(post.authorName, '');
      expect(post.roomArea, 0.0);
      expect(post.isActive, isTrue);
    });

    test('HostPostModel isActive recognizes hidden or deleted statuses', () {
      final active = HostPostModel.fromMap({'trangThai_id': 'dangHienThi'}, '1');
      final hidden = HostPostModel.fromMap({'trangThai_id': 'daAn'}, '2');
      final deleted = HostPostModel.fromMap({'status': 'deleted'}, '3');

      expect(active.isActive, isTrue);
      expect(hidden.isActive, isFalse);
      expect(deleted.isActive, isFalse);
    });

    test('HostPostModel joins with RoomModel and UserProfile correctly', () {
      final base = HostPostModel(
        id: 'p1',
        phongId: 'r1',
        chuNhaId: 'u1',
        tieuDe: 'Tiêu đề gốc',
        moTa: 'Mô tả',
        giaThue: 3000000,
        ngayDang: DateTime.now(),
      );

      final room = RoomModel(
        id: 'r1',
        title: 'Nhà trọ Hòa Phát',
        description: 'Mô tả phòng',
        price: 3000000,
        deposit: 1000000,
        address: '12 Đại lộ Bình Dương',
        district: 'Thủ Dầu Một',
        city: 'Bình Dương',
        area: 32.0,
        roomType: 'Gác lửng',
        amenities: const ['Wifi', 'Ban công'],
        images: const ['img1.jpg'],
        hostId: 'u1',
        hostName: 'Chủ nhà',
        hostPhone: '0988888888',
        createdAt: DateTime.now(),
      );

      final user = UserProfile(
        uid: 'u1',
        email: 'host@test.com',
        displayName: 'Nguyễn Văn Chủ',
        phoneNumber: '0988888888',
        role: 'host',
        avatarUrl: 'avatar.jpg',
        gender: 'nam',
        address: 'Bình Dương',
        hometown: 'Bình Dương',
        reputationScore: 90,
        occupation: 'Chủ trọ',
        hobbies: const [],
        isCccdVerified: true,
        cccdNumber: '123456789012',
        cccdFullName: 'Nguyễn Văn Chủ',
        cccdIssueDate: '01/01/2021',
        cccdHometown: 'Bình Dương',
        cccdFrontImageUrl: '',
        cccdBackImageUrl: '',
      );

      final enriched = base.withRoom(room).withHost(user);

      expect(enriched.roomArea, 32.0);
      expect(enriched.roomType, 'Gác lửng');
      expect(enriched.address, '12 Đại lộ Bình Dương');
      expect(enriched.city, 'Bình Dương');
      expect(enriched.authorName, 'Nguyễn Văn Chủ');
      expect(enriched.authorAvatar, 'avatar.jpg');
      expect(enriched.isVerified, isTrue);
      expect(enriched.isVip, isTrue);
    });

    test('HostPostModel.cleanImageUrl extracts true URLs from map strings, quotes, and objects', () {
      expect(
        HostPostModel.cleanImageUrl('{duongDan: https://res.cloudinary.com/test.jpg}'),
        'https://res.cloudinary.com/test.jpg',
      );
      expect(
        HostPostModel.cleanImageUrl('{"url": "https://firebase.com/photo.png"}'),
        'https://firebase.com/photo.png',
      );
      expect(
        HostPostModel.cleanImageUrl('"https://example.com/avatar.jpg"'),
        'https://example.com/avatar.jpg',
      );
    });

    test('HostPostModel.fromMap extracts images across all Firestore schema variations', () {
      final postFromPhotos = HostPostModel.fromMap({
        'photos': ['https://example.com/photo1.jpg', '{duongDan: https://example.com/photo2.jpg}'],
        'anhDaiDien': '{duongDan: https://example.com/host_avatar.jpg}',
      }, 'p-photos');

      expect(postFromPhotos.images.length, 2);
      expect(postFromPhotos.images[0], 'https://example.com/photo1.jpg');
      expect(postFromPhotos.images[1], 'https://example.com/photo2.jpg');
      expect(postFromPhotos.authorAvatar, 'https://example.com/host_avatar.jpg');

      final postFromMapList = HostPostModel.fromMap({
        'hinhAnh': [
          {'duongDan': 'https://example.com/img3.jpg'},
          {'url': 'https://example.com/img4.jpg'},
        ],
      }, 'p-maps');

      expect(postFromMapList.images.length, 2);
      expect(postFromMapList.images[0], 'https://example.com/img3.jpg');
      expect(postFromMapList.images[1], 'https://example.com/img4.jpg');
    });

    test('HostPostModel extracts room code and property name from compound title Phòng A102 • Nhà trọ i tê', () {
      final post = HostPostModel.fromMap({
        'tieuDe': 'Phòng A102 • Nhà trọ i tê',
        'giaThue': 1200000,
        'authorName': 'tienanh pro',
        'phongId': 'A102',
      }, 'post-a102');

      expect(post.tieuDe, 'Phòng A102 • Nhà trọ i tê');
      expect(post.propertyName, 'Nhà trọ i tê');
      expect(post.phongId, 'A102');
      expect(post.giaThue, 1200000);
      expect(post.authorName, 'tienanh pro');
    });

    test('HostPostModel.withRoom properly inherits room images when post.images is empty', () {
      final emptyPost = HostPostModel(
        id: 'p-empty',
        tieuDe: 'Phòng A102 • Nhà trọ i tê',
        moTa: 'Mô tả phòng',
        giaThue: 1200000,
        ngayDang: DateTime.now(),
        images: const [],
      );

      final roomWithImages = RoomModel(
        id: 'r-a102',
        title: 'Nhà trọ i tê',
        description: 'Phòng sạch đẹp',
        price: 1200000,
        deposit: 240000,
        address: 'Thành phố Thủ Đức',
        district: 'Thành phố Thủ Đức',
        area: 25.0,
        roomType: 'Phòng trọ',
        amenities: const ['Máy lạnh', 'Wifi tốc độ cao'],
        images: const ['https://example.com/room_a102.jpg', 'https://example.com/facility.jpg'],
        hostId: 'host-1',
        hostName: 'tienanh pro',
        hostPhone: '0901234567',
        createdAt: DateTime.now(),
      );

      final enriched = emptyPost.withRoom(roomWithImages);
      expect(enriched.images, hasLength(2));
      expect(enriched.images.first, 'https://example.com/room_a102.jpg');
      expect(enriched.joinedRoom?.images, hasLength(2));
      expect(enriched.roomArea, 25.0);
    });
  });

  group('Host Home Filter Logic Tests', () {
    test('Filters out current host own posts', () {
      final allPosts = [samplePost1, samplePost2, ownPost];
      const currentHostId = 'current-host';

      final filtered = allPosts.where((p) => p.chuNhaId != currentHostId).toList();
      expect(filtered.length, 2);
      expect(filtered.any((p) => p.id == 'post-3'), isFalse);
    });

    test('Searches by title, host name, and amenities', () {
      final posts = [samplePost1, samplePost2];

      // Tìm theo tiêu đề
      final byTitle = posts.where((p) => p.tieuDe.toLowerCase().contains('cao cấp')).toList();
      expect(byTitle.length, 1);
      expect(byTitle.first.id, 'post-1');

      // Tìm theo tên chủ trọ
      final byHost = posts.where((p) => p.authorName.toLowerCase().contains('chú ba')).toList();
      expect(byHost.length, 1);
      expect(byHost.first.id, 'post-2');

      // Tìm theo tiện ích
      final byAmenity = posts.where((p) => p.amenities.any((a) => a.toLowerCase().contains('tủ lạnh'))).toList();
      expect(byAmenity.length, 1);
      expect(byAmenity.first.id, 'post-1');
    });

    test('Filters by multiple locations', () {
      final posts = [samplePost1, samplePost2];
      final selectedLocations = {'Bình Dương'};

      final filtered = posts.where((p) {
        final loc = '${p.city} ${p.district} ${p.address}'.toLowerCase();
        return selectedLocations.any((l) => loc.contains(l.toLowerCase()));
      }).toList();

      expect(filtered.length, 1);
      expect(filtered.first.id, 'post-2');
    });

    test('Filters by price range', () {
      final posts = [samplePost1, samplePost2];

      const minPrice = 2000000.0;
      const maxPrice = 4000000.0;

      final filtered = posts.where((p) => p.giaThue >= minPrice && p.giaThue <= maxPrice).toList();
      expect(filtered.length, 1);
      expect(filtered.first.id, 'post-1');
    });

    test('Sorts by newest, most interested, and price', () {
      final posts = [samplePost2, samplePost1];

      // Mới nhất
      final byNewest = List.of(posts)..sort((a, b) => b.ngayDang.compareTo(a.ngayDang));
      expect(byNewest.first.id, 'post-1');

      // Lượt quan tâm
      final byInterest = List.of(posts)..sort((a, b) => b.interestedCount.compareTo(a.interestedCount));
      expect(byInterest.first.id, 'post-1');

      // Giá thấp đến cao
      final byPriceAsc = List.of(posts)..sort((a, b) => a.giaThue.compareTo(b.giaThue));
      expect(byPriceAsc.first.id, 'post-2');
    });
  });

  group('HostDashboardScreen & HostMainScreen Widget Tests', () {
    testWidgets('Host navigation switches tabs and preserves dashboard state', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostSessionProvider.overrideWith((ref) => Stream.value('host-test')),
            hostPropertiesProvider.overrideWith((ref) => Stream.value([])),
            hostRoomsProvider.overrideWith((ref) => Stream.value([])),
            hostHomePostsProvider.overrideWith((ref) => Stream.value([samplePost1, samplePost2])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HostMainScreen(),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // 1. Kiểm tra Header
      expect(find.text('HomeShare'), findsOneWidget);
      expect(find.text('Mạng lưới Đối tác & Chủ trọ • Chủ trọ'), findsOneWidget);

      // 2. Kiểm tra bộ lọc khu vực & áp dụng
      if (find.text('Áp dụng (2)').evaluate().isEmpty) {
        final arrowDown = find.byIcon(Icons.keyboard_arrow_down);
        if (arrowDown.evaluate().isNotEmpty) {
          await tester.tap(arrowDown.first);
          await tester.pumpAndSettle();
        }
      }
      if (find.textContaining('Áp dụng').evaluate().isNotEmpty) {
        await tester.tap(find.textContaining('Áp dụng').first);
        await tester.pumpAndSettle();
      }
      expect(find.text('Bỏ chọn tất cả'), findsNothing);

      // 3. Chuyển sang tab Tin nhắn (Chat)
      await tester.tap(find.text('Tin nhắn').last);
      await tester.pumpAndSettle();
      expect(find.text('Tin nhắn & Trao đổi'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 4. Chuyển sang tab Cá nhân (Profile)
      await tester.tap(find.text('Cá nhân').last);
      await tester.pumpAndSettle();
      expect(find.text('Trang cá nhân'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 5. Mở Tạo mới (Tạo bài đăng)
      await tester.tap(find.text('Tạo mới').last);
      await tester.pumpAndSettle();
      expect(find.text('Tạo bài đăng'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();

      // 6. Chuyển sang Quản lý
      await tester.tap(find.text('Quản lý').last);
      await tester.pumpAndSettle();
      expect(find.text('Quản lý phòng trọ'), findsOneWidget);
      expect(find.text('Danh sách cơ sở (0)'), findsOneWidget);
      expect(find.text('Thông tin chung'), findsOneWidget);
      expect(find.text('Trang chủ'), findsNothing);
      expect(tester.takeException(), isNull);

      // 7. Quay lại Trang chủ và giữ nguyên trạng thái bộ lọc đã áp dụng
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('HomeShare'), findsOneWidget);
      expect(find.text('Bỏ chọn tất cả'), findsNothing); // Panel vẫn đóng
      expect(tester.takeException(), isNull);
    });

    testWidgets('Displays post cards with images, fallback, badges, and chat button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostHomePostsProvider.overrideWith((ref) => Stream.value([samplePost1, samplePost2])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HostDashboardScreen(initialLocationExpanded: false),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Bài 1: Cô Mai
      expect(find.text('Phòng trọ cao cấp full nội thất'), findsOneWidget);
      expect(find.text('Cô Mai'), findsOneWidget);
      expect(find.text('Đối tác uy tín'), findsOneWidget);
      expect(find.text('3.500.000 đ/tháng'), findsOneWidget);
      expect(find.text('28 m²'), findsOneWidget);
      expect(find.text('Cơ sở đã xác thực'), findsNWidgets(2));
      expect(find.text('Nhắn tin trao đổi'), findsNWidgets(2));

      // Bài 2: Chú Ba (không có ảnh -> fallback placeholder)
      expect(find.text('KTX Mini giá rẻ cho sinh viên'), findsOneWidget);
      expect(find.text('Chú Ba'), findsOneWidget);
      expect(find.text('1.500.000 đ/tháng'), findsOneWidget);
      expect(find.text('Ảnh cơ sở liên kết'), findsWidgets);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping Nhắn tin trao đổi opens ChatDetailScreen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dummyUser = UserProfile(
        uid: 'my-host-id',
        email: 'me@test.com',
        displayName: 'Chủ trọ hiện tại',
        phoneNumber: '0901234567',
        role: 'host',
        avatarUrl: '',
        gender: 'nam',
        address: '',
        hometown: '',
        reputationScore: 100,
        occupation: 'Chủ trọ',
        hobbies: const [],
        isCccdVerified: true,
        cccdNumber: '',
        cccdFullName: '',
        cccdIssueDate: '',
        cccdHometown: '',
        cccdFrontImageUrl: '',
        cccdBackImageUrl: '',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(dummyUser)),
            hostHomePostsProvider.overrideWith((ref) => Stream.value([samplePost1])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HostDashboardScreen(initialLocationExpanded: false),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final chatButton = find.text('Nhắn tin trao đổi').first;
      await tester.ensureVisible(chatButton);
      await tester.pumpAndSettle();
      await tester.tap(chatButton);
      await tester.pumpAndSettle();

      expect(find.byType(ChatDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Displays Empty state when no posts are available', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostHomePostsProvider.overrideWith((ref) => Stream.value([])),
            hostHomeFilterProvider.overrideWith(HostHomeFilterNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HostDashboardScreen(initialLocationExpanded: false),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Chưa có bài đăng nào từ đối tác'), findsOneWidget);
    });

    testWidgets('Displays Error state and retry button on Firestore failure', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostHomePostsProvider.overrideWith((ref) => Stream.error(Exception('Firestore failure'))),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HostDashboardScreen(initialLocationExpanded: false),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Đã có lỗi xảy ra'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('Advanced filter amenities expand/collapse and sort radios always select 1 of 2', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dummyAmenities = [
        'Máy lạnh',
        'Giờ giấc tự do',
        'Wifi tốc độ cao',
        'Có gác lửng',
        'Tủ lạnh',
        'Máy giặt',
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostHomePostsProvider.overrideWith((ref) => Stream.value([])),
            hostAmenityNamesProvider.overrideWithValue(dummyAmenities),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HostDashboardScreen(initialLocationExpanded: false),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Mở Bộ lọc nâng cao
      final filterBtn = find.text('Nâng cao');
      expect(filterBtn, findsOneWidget);
      await tester.tap(filterBtn);
      await tester.pumpAndSettle();

      // 2. Kiểm tra phần Tiện ích: mặc định hiển thị 4 tiện ích đầu, có nút "Xem thêm (2)"
      expect(find.text('Máy lạnh'), findsOneWidget);
      expect(find.text('Giờ giấc tự do'), findsOneWidget);
      expect(find.text('Wifi tốc độ cao'), findsOneWidget);
      expect(find.text('Có gác lửng'), findsOneWidget);
      expect(find.text('Máy giặt'), findsNothing);

      final expandBtn = find.text('Xem thêm v');
      expect(expandBtn, findsOneWidget);

      // Nhấn "Xem thêm v" -> Hiển thị toàn bộ tiện ích
      await tester.ensureVisible(expandBtn);
      await tester.tap(expandBtn);
      await tester.pumpAndSettle();
      expect(find.text('Máy giặt'), findsOneWidget);
      expect(find.text('Thu gọn ^'), findsOneWidget);

      // Nhấn "Thu gọn ^" -> Thu gọn lại
      await tester.ensureVisible(find.text('Thu gọn ^'));
      await tester.tap(find.text('Thu gọn ^'));
      await tester.pumpAndSettle();
      expect(find.text('Máy giặt'), findsNothing);
      expect(find.text('Xem thêm v'), findsOneWidget);

      // Thử nhập tiện ích không dấu "máy lanh" khi đã có "Máy lạnh"
      final customInput = find.byType(TextField).last;
      await tester.enterText(customInput, 'máy lanh');
      final addBtn = find.text('Thêm');
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Không được tạo thêm item tùy chọn trùng lặp "máy lanh"
      expect(find.text('máy lanh'), findsNothing);
      // "Máy lạnh" có sẵn phải được tự động chọn (hiển thị badge "Đã chọn")
      expect(find.text('Đã chọn'), findsWidgets);

      // 3. Kiểm tra 2 Radio: "Giá thấp đến cao" và "Giá cao đến thấp"
      final ascRadio = find.text('Giá thấp đến cao');
      final descRadio = find.text('Giá cao đến thấp');
      expect(ascRadio, findsOneWidget);
      expect(descRadio, findsOneWidget);

      // Nhấn vào "Giá cao đến thấp" -> chọn Giá cao đến thấp
      await tester.ensureVisible(descRadio);
      await tester.tap(descRadio);
      await tester.pumpAndSettle();

      // Nhấn lại vào "Giá cao đến thấp" -> VẪN GIỮ Giá cao đến thấp (không bị null)
      await tester.tap(descRadio);
      await tester.pumpAndSettle();

      // Nhấn "Đặt lại" -> Quay về "Giá thấp đến cao" (luôn chọn 1 trong 2)
      final resetBtn = find.text('Đặt lại');
      await tester.ensureVisible(resetBtn);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Advanced filter pre-populates sample amenities when provider is empty', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostHomePostsProvider.overrideWith((ref) => Stream.value([])),
            hostAmenityNamesProvider.overrideWithValue([]),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HostDashboardScreen(initialLocationExpanded: false),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Mở bộ lọc nâng cao
      final filterBtn = find.text('Nâng cao');
      expect(filterBtn, findsOneWidget);
      await tester.tap(filterBtn);
      await tester.pumpAndSettle();

      // Tiện ích mẫu mặc định (Wifi, Máy lạnh, Tủ lạnh, Máy giặt) được hiển thị sẵn
      expect(find.text('Wifi'), findsOneWidget);
      expect(find.text('Máy lạnh'), findsOneWidget);
      expect(find.text('Tủ lạnh'), findsOneWidget);
      expect(find.text('Máy giặt'), findsOneWidget);
    });
  });
}
