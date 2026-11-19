import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime code no longer accesses the legacy root rooms collection', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList()
      ..add(File('firestore.rules'));

    final violations = <String>[];
    final forbidden = <RegExp>[
      RegExp(r'''\.collection\(\s*['"]rooms['"]\s*\)'''),
      RegExp(r'FirestoreCollections\.(rooms|publicRooms)\b'),
      RegExp(r'''docHostMatches\(\s*['"]rooms['"]'''),
      RegExp(r'''['"]rooms/\$'''),
    ];

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final pattern in forbidden) {
        for (final match in pattern.allMatches(source)) {
          final lineNumber = '\n'.allMatches(source.substring(0, match.start)).length + 1;
          final line = source.split('\n')[lineNumber - 1].trim();
          violations.add('${file.path}:$lineNumber: $line');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Không được đọc/ghi collection Firestore gốc `rooms` nữa. '
          'Dùng `host_rooms` cho kho phòng và `posts` cho bài đăng:\n'
          '${violations.join('\n')}',
    );
  });
}
