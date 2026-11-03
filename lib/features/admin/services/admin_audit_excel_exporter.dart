import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class AdminAuditExcelExporter {
  static Uint8List create(List<List<Object?>> rows) {
    final columnCount = rows.isEmpty ? 1 : rows.first.length;
    final lastColumn = _columnName(columnCount);
    final rowXml = StringBuffer();

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final rowNumber = rowIndex + 1;
      rowXml.write('<row r="$rowNumber">');
      for (var columnIndex = 0; columnIndex < rows[rowIndex].length; columnIndex++) {
        rowXml.write(
          _cellXml(
            _columnName(columnIndex + 1),
            rowNumber,
            rows[rowIndex][columnIndex],
          ),
        );
      }
      rowXml.write('</row>');
    }

    final archive = Archive()
      ..addFile(
        _archiveFile(
          '[Content_Types].xml',
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''',
        ),
      )
      ..addFile(
        _archiveFile(
          '_rels/.rels',
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''',
        ),
      )
      ..addFile(
        _archiveFile(
          'xl/workbook.xml',
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="Lich su" sheetId="1" r:id="rId1"/></sheets>
</workbook>''',
        ),
      )
      ..addFile(
        _archiveFile(
          'xl/_rels/workbook.xml.rels',
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''',
        ),
      )
      ..addFile(
        _archiveFile(
          'xl/worksheets/sheet1.xml',
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
<sheetData>$rowXml</sheetData>
${rows.length > 1 ? '<autoFilter ref="A1:$lastColumn${rows.length}"/>' : ''}
</worksheet>''',
        ),
      );

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded ?? <int>[]);
  }

  static ArchiveFile _archiveFile(String name, String contents) {
    final bytes = utf8.encode(contents);
    return ArchiveFile(name, bytes.length, bytes);
  }

  static String _cellXml(String column, int row, Object? value) {
    final reference = '$column$row';
    if (value is num && value.isFinite) {
      return '<c r="$reference" t="n"><v>$value</v></c>';
    }

    final text = _escapeXml(value?.toString() ?? '');
    return '<c r="$reference" t="inlineStr"><is><t xml:space="preserve">$text</t></is></c>';
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _columnName(int column) {
    var value = column;
    final name = StringBuffer();
    while (value > 0) {
      value--;
      name.writeCharCode(65 + value % 26);
      value ~/= 26;
    }
    return name.toString().split('').reversed.join();
  }
}
