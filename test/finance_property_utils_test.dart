import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/features/host/utils/finance_property_utils.dart';

void main() {
  test('Booking with listing ID resolves through listing to existing room', () {
    final rooms = [
      RoomModel.fromMap({'propertyId': 'toan-bel'}, 'existing-room'),
    ];
    final posts = [
      {'id': 'listing-id', 'roomId': 'existing-room'},
    ];
    expect(
      financePropertyId({'roomId': 'listing-id'}, rooms, posts: posts),
      'toan-bel',
    );
    expect(
      financePropertyId({'postId': 'listing-id'}, rooms, posts: posts),
      'toan-bel',
    );
    expect(
      financePropertyId({'roomId': 'unrelated'}, rooms, posts: posts),
      isNull,
    );
  });
  final rooms = [
    RoomModel.fromMap({'propertyId': 'house-a'}, 'room-a'),
    RoomModel.fromMap({'propertyId': 'house-b'}, 'room-b'),
  ];
  test('Resolves current and legacy property and room references', () {
    expect(financePropertyId({'propertyId': 'house-a'}, rooms), 'house-a');
    expect(financePropertyId({'property_id': 'house-b'}, rooms), 'house-b');
    expect(
      financePropertyId({
        'propertyId': '',
        'bat_dong_san_id': 'house-a',
      }, rooms),
      'house-a',
    );
    expect(financePropertyId({'roomId': 'room-a'}, rooms), 'house-a');
    expect(financePropertyId({'phongId': 'room-b'}, rooms), 'house-b');
    expect(
      financePropertyId({'roomId': '', 'phongId': 'room-b'}, rooms),
      'house-b',
    );
  });
  test(
    'Explicit property takes precedence and unknown rooms remain unassigned',
    () {
      expect(
        financePropertyId({'propertyId': 'house-a', 'roomId': 'room-b'}, rooms),
        'house-a',
      );
      expect(financePropertyId({'roomId': 'missing'}, rooms), isNull);
      expect(financePropertyId({}, rooms), isNull);
    },
  );
}
