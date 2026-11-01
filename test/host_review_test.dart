import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/constants/app_colors.dart';
import 'package:home_share/core/constants/firestore_collections.dart';
import 'package:home_share/core/services/host_review_service.dart';
import 'package:home_share/core/utils/host_reputation.dart';
import 'package:home_share/core/utils/host_review_policy.dart';
import 'package:home_share/data/models/booking_model.dart';
import 'package:home_share/data/models/host_review_model.dart';
import 'package:home_share/data/models/resident_model.dart';
import 'package:home_share/features/auth/providers/auth_provider.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/profile/widgets/host_reputation_bar.dart';
import 'package:home_share/features/profile/widgets/host_review_sheet.dart';
import 'package:home_share/features/profile/widgets/host_reviews_section.dart';

BookingRequestModel _booking({
  String id = 'bk1',
  String renterId = 'renter1',
  String hostId = 'host1',
  String status = 'dangO',
  DateTime? createdAt,
}) {
  return BookingRequestModel(
    id: id,
    renterId: renterId,
    renterName: 'An',
    renterPhone: '0901000000',
    roomId: 'room1',
    roomTitle: 'Phòng test',
    roomAddress: 'Q1',
    roomPrice: 3000000,
    hostId: hostId,
    hostName: 'Lan',
    status: status,
    moveInDate: DateTime(2026, 10, 1),
    createdAt: createdAt ?? DateTime(2026, 9, 1),
  );
}

HostReviewModel _review({
  String id = 'bk1',
  String hostId = 'host1',
  int rating = 5,
  String comment = 'Ổn',
}) {
  return HostReviewModel(
    id: id,
    hostId: hostId,
    reviewerId: 'renter1',
    reviewerName: 'An',
    rating: rating,
    comment: comment,
    bookingId: id,
    createdAt: DateTime(2026, 10, 20),
  );
}

void main() {
  group('HostReputation — chỉ chủ trọ', () {
    test('người thuê và admin không có thanh uy tín', () {
      expect(HostReputation.isHostRole('renter'), isFalse);
      expect(HostReputation.isHostRole('tenant'), isFalse);
      expect(HostReputation.isHostRole('nguoidung'), isFalse);
      expect(HostReputation.isHostRole('admin'), isFalse);
    });

    test('chủ trọ mới được gắn thanh uy tín', () {
      expect(HostReputation.isHostRole('host'), isTrue);
      expect(HostReputation.isHostRole('landlord'), isTrue);
      expect(HostReputation.isHostRole('chutro'), isTrue);
      expect(HostReputation.isHostRole('chu_tro'), isTrue);
    });

    test('điểm 0–100, màu và nhãn khớp thanh uy tín', () {
      expect(HostReputation.clampScore(-8), 0);
      expect(HostReputation.clampScore(140), 100);
      expect(HostReputation.scoreText(80), '80/100');
      expect(HostReputation.barColor(80), AppColors.success);
      expect(HostReputation.label(80), 'Uy tín cao');
      expect(HostReputation.barColor(50), AppColors.warning);
      expect(HostReputation.label(50), 'Uy tín trung bình');
      expect(HostReputation.barColor(49), AppColors.danger);
      expect(HostReputation.label(20), 'Uy tín thấp');
    });

    test('reputationScore = max(0, 20 * R - P), hiện tại P = 0', () {
      expect(HostReputation.fromAverage(5), 100);
      expect(HostReputation.fromAverage(4), 80);
      expect(HostReputation.fromAverage(2.5), 50);
      expect(HostReputation.fromAverage(1), 20);
      expect(HostReputation.fromAverage(null), 100);
      expect(HostReputation.fromAverage(2.5, penalty: 10), 40);
      expect(HostReputation.fromAverage(1, penalty: 50), 0);
    });

    test('sao uy tín = điểm / 20, không hiện thang 100', () {
      expect(HostReputation.starsFromScore(100), 5.0);
      expect(HostReputation.starsFromScore(80), 4.0);
      expect(HostReputation.starsFromScore(50), 2.5);
      expect(HostReputation.starsText(100), '5.0');
      expect(HostReputation.starsText(80), '4.0');
      expect(HostReputation.starsText(48), '2.4');
    });
  });

  group('HostReviewPolicy', () {
    test('sao phải từ 1 đến 5', () {
      expect(HostReviewPolicy.isValidRating(0), isFalse);
      expect(HostReviewPolicy.isValidRating(6), isFalse);
      expect(HostReviewPolicy.isValidRating(1), isTrue);
      expect(HostReviewPolicy.isValidRating(5), isTrue);
    });

    test('không tự đánh giá chính mình', () {
      expect(HostReviewPolicy.canReviewOwnHost('host1', 'host1'), isFalse);
      expect(HostReviewPolicy.canReviewOwnHost('renter1', 'host1'), isTrue);
      expect(HostReviewPolicy.canReviewOwnHost('', 'host1'), isFalse);
    });

    test('đã nhận phòng thì được đánh giá, kể cả sau khi bị đuổi / trả phòng', () {
      expect(HostReviewPolicy.isReviewableBooking(_booking(status: 'active')), isTrue);
      expect(HostReviewPolicy.isReviewableBooking(_booking(status: 'dangO')), isTrue);
      expect(HostReviewPolicy.isReviewableBooking(_booking(status: 'daNhanPhong')), isTrue);
      expect(HostReviewPolicy.isReviewableBooking(_booking(status: 'checked_out')), isTrue);
      expect(HostReviewPolicy.isReviewableBooking(_booking(status: 'moved_out')), isTrue);
    });

    test('đơn đã duyệt, chờ nhận phòng, chờ hoặc hủy thì chưa được đánh giá', () {
      expect(HostReviewPolicy.isReviewableBooking(_booking(status: 'approved')), isFalse);
      expect(HostReviewPolicy.isReviewableBooking(_booking(status: 'deposit_paid')), isFalse);
      expect(HostReviewPolicy.isReviewableBooking(_booking(status: 'daCoc')), isFalse);
      expect(HostReviewPolicy.isReviewableBooking(_booking(status: 'choNhanPhong')), isFalse);
      expect(HostReviewPolicy.isReviewableBooking(_booking(status: 'pending')), isFalse);
      expect(HostReviewPolicy.isReviewableBooking(_booking(status: 'cancelled')), isFalse);
    });

    test('không gửi trùng cùng một bookingId', () {
      final eligible = HostReviewPolicy.firstEligibleBooking(
        reviewerId: 'renter1',
        hostId: 'host1',
        bookings: [_booking()],
        reviewedBookingIds: {'bk1'},
      );
      expect(eligible, isNull);
    });

    test('chọn booking đủ điều kiện mới nhất khi chưa đánh giá', () {
      final eligible = HostReviewPolicy.firstEligibleBooking(
        reviewerId: 'renter1',
        hostId: 'host1',
        bookings: [
          _booking(id: 'old', createdAt: DateTime(2026, 8, 1)),
          _booking(id: 'new', createdAt: DateTime(2026, 9, 1)),
        ],
        reviewedBookingIds: {},
      );
      expect(eligible?.id, 'new');
    });

    test('người ở ghép đang ở được đánh giá chủ trọ dù không có đơn bookings', () {
      final eligible = HostReviewPolicy.firstEligibleResident(
        reviewerId: 'roommate1',
        hostId: 'host1',
        residents: [
          ResidentModel(
            id: 'res_og_1',
            periodId: 'p1',
            roomId: 'room1',
            userId: 'roommate1',
            fullName: 'Bạn ở ghép',
            formId: 'oGhep',
            statusId: 'dangO',
            moveInDate: DateTime(2026, 10, 2),
          ),
        ],
        roomHostByRoomId: const {'room1': 'host1'},
        reviewedBookingIds: {},
      );
      expect(eligible?.id, 'res_og_1');
      expect(eligible?.renterId, 'roommate1');
      expect(eligible?.hostId, 'host1');
      expect(HostReviewPolicy.isReviewableBooking(eligible!), isTrue);
    });

    test('người ở ghép đã rời đi vẫn được đánh giá chủ trọ', () {
      final movedOut = HostReviewPolicy.firstEligibleResident(
        reviewerId: 'roommate1',
        hostId: 'host1',
        residents: [
          ResidentModel(
            id: 'res_left',
            periodId: 'p3',
            roomId: 'room1',
            userId: 'roommate1',
            fullName: 'Bạn ở ghép',
            formId: 'oGhep',
            statusId: 'daRoi',
            moveInDate: DateTime(2026, 9, 1),
            moveOutDate: DateTime(2026, 10, 1),
          ),
        ],
        roomHostByRoomId: const {'room1': 'host1'},
        reviewedBookingIds: {},
      );
      expect(movedOut?.id, 'res_left');
      expect(HostReviewPolicy.isReviewableBooking(movedOut!), isTrue);
    });

    test('người ở ghép phòng chủ khác thì không được đánh giá', () {
      final otherHost = HostReviewPolicy.firstEligibleResident(
        reviewerId: 'roommate1',
        hostId: 'host1',
        residents: [
          ResidentModel(
            id: 'res_other',
            periodId: 'p2',
            roomId: 'room2',
            userId: 'roommate1',
            fullName: 'Bạn ở ghép',
            formId: 'oGhep',
            statusId: 'dangO',
            moveInDate: DateTime(2026, 10, 2),
          ),
        ],
        roomHostByRoomId: const {'room2': 'host2'},
        reviewedBookingIds: {},
      );
      expect(otherHost, isNull);
    });
  });

  group('HostReviewStats và schema', () {
    test('chưa có đánh giá thì không bịa điểm trung bình', () {
      const stats = HostReviewStats();
      expect(stats.average, isNull);
      expect(stats.displayAverage, 'Chưa có đánh giá');
      expect(stats.count, 0);
    });

    test('điểm trung bình làm tròn 1 chữ số, bỏ rating lệch', () {
      final stats = HostReviewStats.fromReviews([
        _review(id: 'a', rating: 4),
        _review(id: 'b', rating: 5),
        _review(id: 'bad', rating: 0),
        _review(id: 'c', rating: 9),
      ]);
      expect(stats.count, 2);
      expect(stats.average, 4.5);
      expect(stats.displayAverage, '4.5/5');
    });

    test('client không ghi averageRating vào document', () {
      final map = _review().toMap();
      expect(map.containsKey('averageRating'), isFalse);
      expect(map.containsKey('average'), isFalse);
      expect(map.keys, containsAll([
        HostReviewFields.hostId,
        HostReviewFields.reviewerId,
        HostReviewFields.rating,
        HostReviewFields.comment,
        HostReviewFields.bookingId,
        HostReviewFields.createdAt,
      ]));
    });
  });

  group('UI hồ sơ chủ trọ', () {
    testWidgets('thanh uy tín hiện điểm hiện tại trên thanh', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HostReputationBar(score: 80)),
        ),
      );
      expect(find.text('Độ uy tín'), findsOneWidget);
      expect(find.text('Uy tín cao'), findsOneWidget);
      expect(find.text('80/100'), findsOneWidget);
    });

    testWidgets('hồ sơ chủ trọ: trung bình sao, nhận xét, nút đánh giá khi đủ điều kiện', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostReviewsProvider.overrideWith(
              (ref, hostId) => Stream.value([
                _review(rating: 5, comment: 'Phòng sạch'),
                _review(id: 'bk2', rating: 4, comment: 'Ổn'),
              ]),
            ),
            eligibleHostReviewBookingProvider.overrideWith(
              (ref, hostId) => _booking(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HostReviewsSection(
                hostId: 'host1',
                hostName: 'Lan',
                reputationScore: 92,
                showReviewButton: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HostReputationBar), findsOneWidget);
      expect(find.text('90/100'), findsOneWidget);
      expect(find.text('4.5/5'), findsOneWidget);
      expect(find.text('Phòng sạch'), findsOneWidget);
      expect(find.text('Đánh giá chủ trọ'), findsOneWidget);
    });

    testWidgets('chưa có đánh giá thì hiện trạng thái trống, không bịa sao', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostReviewsProvider.overrideWith(
              (ref, hostId) => Stream.value(const <HostReviewModel>[]),
            ),
            eligibleHostReviewBookingProvider.overrideWith((ref, hostId) => null),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HostReviewsSection(
                hostId: 'host1',
                hostName: 'Lan',
                reputationScore: 100,
                showReviewButton: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có đánh giá'), findsOneWidget);
      expect(find.text('Chưa có nhận xét nào.'), findsOneWidget);
      expect(find.text('100/100'), findsOneWidget);
      expect(find.text('Đánh giá chủ trọ'), findsNothing);
    });

    testWidgets('1 sao và 4 sao thì thanh uy tín là 50/100', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostReviewsProvider.overrideWith(
              (ref, hostId) => Stream.value([
                _review(id: 'bk1', rating: 4, comment: 'ok baby'),
                _review(id: 'bk2', rating: 1, comment: 'chu tro ham'),
              ]),
            ),
            eligibleHostReviewBookingProvider.overrideWith((ref, hostId) => null),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HostReviewsSection(
                hostId: 'host1',
                hostName: 'QA',
                reputationScore: 100,
                showReviewButton: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2.5/5'), findsOneWidget);
      expect(find.text('50/100'), findsOneWidget);
      expect(find.text('Uy tín trung bình'), findsOneWidget);
    });

    testWidgets('chưa đăng nhập thì không gửi được đánh giá', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => null),
            userProfileProvider.overrideWith((ref) => Stream<UserProfile?>.value(null)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HostReviewSheet(
                hostId: 'host1',
                hostName: 'Lan',
                bookingId: 'bk1',
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Gửi đánh giá'));
      await tester.pump();
      expect(find.text('Vui lòng đăng nhập để đánh giá.'), findsOneWidget);
    });
  });
}
