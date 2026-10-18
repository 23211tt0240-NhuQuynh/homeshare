import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/utils/room_identity.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/features/host/screens/host_create_screen.dart';
import 'host_management_test.dart' as fixture;

void main() {
  // Chủ trọ - Kiểm thử ID ngắn - Luồng đi: Sinh ID không có tên nhà,
  // tầng hay ký tự khó đọc; không lặp trong tập kiểm tra.
  test('Room ID has 12 readable random characters', () {
    final ids = List.generate(1000, (_) => newRoomId());
    expect(ids.every(isShortRoomId), isTrue);
    expect(ids.toSet().length, ids.length);
    expect(isShortRoomId('NTLVM03-02'), isFalse);
  });

  // Chủ trọ - Một khóa liên kết - Luồng đi: Dùng document ID làm
  // nguồn chính; payload mới chỉ lưu id/title, vẫn đọc được mã cũ.
  test('Stored room identity has no roomCode or operationId', () {
    final id = newRoomId();
    final room = RoomModel.fromMap({
      ...fixture.makeRoom('old').toMap(),
      'id': 'wrong-embedded-id',
      'title': 'NTLVM03-02',
    }, id);
    expect(room.id, id);
    final payload = room.toMap();
    expect(payload['id'], id);
    expect(payload['title'], 'NTLVM03-02');
    expect(payload.containsKey('roomCode'), isFalse);
    expect(payload.containsKey('operationId'), isFalse);
    expect(
      RoomModel.fromMap({'roomCode': 'A101'}, 'legacy-id').roomCode,
      'A101',
    );
  });

  // Chủ trọ - Form mã phòng - Luồng đi: Chỉ đọc, không có chữ tự sinh;
  // ID không đổi khi đổi tầng, tên do người dùng nhập được giữ nguyên.
  testWidgets('Create shows stable ID, locks editing and keeps manual title', (
    tester,
  ) async {
    fixture.phone(tester);
    final repo = fixture.TestRepository()..properties.add(fixture.house);
    addTearDown(repo.close);
    await tester.pumpWidget(
      fixture.app(
        const HostCreateScreen(propertyId: 'house-1', startWithRoom: true),
        repo,
      ),
    );
    await tester.pumpAndSettle();
    final code = find.byKey(const ValueKey('host_field_code'));
    final id = tester.widget<TextFormField>(code).controller!.text;
    expect(isShortRoomId(id), isTrue);
    expect(find.text('Mã phòng (tự sinh)'), findsNothing);
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: code, matching: find.byType(TextField)),
          )
          .readOnly,
      isTrue,
    );
    await fixture.enter(tester, 'title', 'NTLVM03-02');
    tester
        .widget<DropdownButtonFormField<int>>(
          find.byKey(const ValueKey('host_floor_house-1_2')),
        )
        .onChanged!(2);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(code).controller!.text, id);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('host_field_title')))
          .controller!
          .text,
      'NTLVM03-02',
    );
    expect(tester.takeException(), isNull);
  });
}
