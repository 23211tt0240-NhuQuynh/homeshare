import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/host/repositories/checkin_checkout_repository.dart';
import 'roommate_resident_merge_regression_test.dart' show Store;

void main() {
  for (final departing in ['primary', 'mate']) {
    test(
      'checkout $departing preserves the other resident and shared period',
      () async {
        final store = Store();
        addTearDown(store.changes.close);
        store.rows['host_rooms/room'] = {
          'propertyId': 'property',
          'hostId': 'host',
          'status': 'occupied',
          'contractId': 'contract',
        };
        store.rows['periods/period'] = {
          'roomId': 'room',
          'renterId': 'primary',
          'status': 'dangO',
        };
        for (final user in ['primary', 'mate']) {
          store.rows['residents/$user'] = {
            'roomId': 'room',
            'periodId': 'period',
            'userId': user,
            'fullName': user,
            'statusId': 'dangO',
            'status': 'active',
            'formId': user == 'primary' ? 'chinh' : 'oGhep',
            'moveInDate': Timestamp.now(),
          };
        }
        final repo = CheckinCheckoutRepository(firestore: store);
        Future<void> checkout(String user) => repo.performCheckout(
          roomId: 'room',
          periodId: 'period',
          renterId: user,
          residentId: user,
          initialDeposit: 0,
          deductionAmount: 0,
          note: '',
        );
        final items = await repo.watchCheckoutItems('host').first;
        expect(
          items
              .where((item) => !item.isCompleted)
              .map((item) => item.residentId)
              .toSet(),
          {'primary', 'mate'},
        );
        await checkout(departing);
        final other = departing == 'primary' ? 'mate' : 'primary';
        expect(store.rows['residents/$departing']!['status'], 'moved_out');
        expect(store.rows['residents/$other']!['status'], 'active');
        expect(store.rows['periods/period']!['status'], 'dangO');
        expect(store.rows['host_rooms/room']!['status'], 'occupied');
        expect(store.rows['host_rooms/room']!['contractId'], 'contract');
        final records = store.rows.entries.where(
          (e) => e.key.startsWith('checkout_records/'),
        );
        expect(records.single.value['residentId'], departing);
        await expectLater(checkout(departing), throwsStateError);
        await checkout(other);
        expect(store.rows['periods/period']!['status'], 'daKetThuc');
        expect(store.rows['host_rooms/room']!['status'], 'available');
      },
    );
  }
}
