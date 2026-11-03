import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/features/host/utils/finance_property_utils.dart';

void main() {
  final rooms = [
    RoomModel.fromMap({'propertyId': 'house-a'}, 'room-a'),
    RoomModel.fromMap({'propertyId': 'house-b'}, 'room-b'),
  ];
  test('Current and legacy property and room references resolve', () {
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
  test('Explicit property wins and unknown rooms stay unassigned', () {
    expect(
      financePropertyId({'propertyId': 'house-a', 'roomId': 'room-b'}, rooms),
      'house-a',
    );
    expect(financePropertyId({'roomId': 'missing'}, rooms), isNull);
  });
  test('Listing ID on booking resolves through existing room to property', () {
    final posts = [
      {'id': 'listing', 'roomId': 'room-a'},
    ];
    expect(
      financePropertyId({'roomId': 'listing'}, rooms, posts: posts),
      'house-a',
    );
    expect(
      financePropertyId({'postId': 'listing'}, rooms, posts: posts),
      'house-a',
    );
    expect(
      financePropertyId({'roomId': 'unknown'}, rooms, posts: posts),
      isNull,
    );
  });
}
