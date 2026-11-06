import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/utils/default_room_name.dart';
import 'package:home_share/data/models/room_model.dart';

void main() {
  RoomModel room(String title, {String property = 'd', int floor = 8}) =>
      RoomModel.fromMap({
        'title': title,
        'propertyId': property,
        'floor': floor,
      }, title);

  String name(List<RoomModel> rooms, {String propertyName = 'Nhà D'}) =>
      defaultRoomName(
        propertyId: 'd',
        propertyName: propertyName,
        floor: 8,
        rooms: rooms,
      );

  test('uses the house abbreviation and padded floor and sequence', () {
    expect(name([]), 'D08-01');
    expect(name([room('D08-01')]), 'D08-02');
    expect(name([], propertyName: 'Nhà An Bình'), 'AB08-01');
  });

  test(
    'counts custom names and scopes the sequence to the house and floor',
    () {
      expect(
        name([
          room('Phòng ban công'),
          room('D08-99', property: 'other'),
          room('D09-99', floor: 9),
        ]),
        'D08-02',
      );
    },
  );

  test('continues after the highest existing number despite gaps', () {
    expect(name([room('D08-01'), room('D08-05')]), 'D08-06');
  });
}
