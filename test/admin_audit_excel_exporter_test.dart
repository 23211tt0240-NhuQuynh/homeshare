import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/admin/services/admin_audit_excel_exporter.dart';

void main() {
  test('creates an XLSX workbook with escaped cell text and numeric cells', () {
    final bytes = AdminAuditExcelExporter.create([
      ['Thao tác', 'Giá trị'],
      ['Cập nhật <phí> & hoa hồng', 125000],
    ]);

    final archive = ZipDecoder().decodeBytes(bytes);
    final worksheet = archive.findFile('xl/worksheets/sheet1.xml');

    expect(archive.findFile('[Content_Types].xml'), isNotNull);
    expect(worksheet, isNotNull);
    final xml = utf8.decode(worksheet!.content);
    expect(xml, contains('Cập nhật &lt;phí&gt; &amp; hoa hồng'));
    expect(xml, contains('<c r="B2" t="n"><v>125000</v></c>'));
    expect(xml, contains('<autoFilter ref="A1:B2"/>'));
  });
}
