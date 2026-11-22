import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';

/// Một dòng nhật ký thao tác của Admin dùng để xuất báo cáo tháng.
class AdminAuditExcelEntry {
  final String id;
  final DateTime time;
  final String performer;
  final String category;
  final String action;
  final String target;
  final String detail;
  final num? amount;

  const AdminAuditExcelEntry({
    required this.id,
    required this.time,
    required this.performer,
    required this.category,
    required this.action,
    required this.target,
    required this.detail,
    this.amount,
  });
}

enum _XlStyle {
  normal,
  title,
  header,
  money,
  bold,
  moneyTotal,
  cell,
  note,
  center,
  section,
  centerTotal,
}

class _XlCell {
  final Object? value;
  final _XlStyle style;
  const _XlCell(this.value, [this.style = _XlStyle.normal]);
}

class _XlSheet {
  final String name;
  final List<List<_XlCell>> rows;
  final List<double> columnWidths;
  final List<String> merges;

  /// Dòng tiêu đề cột (bắt đầu từ 1) để cố định + bộ lọc. Null nếu không dùng.
  final int? headerRow;

  /// Dòng dữ liệu cuối cùng thuộc vùng bộ lọc.
  final int? filterLastRow;

  const _XlSheet({
    required this.name,
    required this.rows,
    required this.columnWidths,
    this.merges = const [],
    this.headerRow,
    this.filterLastRow,
  });
}

/// Xuất báo cáo hoạt động Admin theo tháng ra file .xlsx (2 sheet:
/// "Tổng hợp" và "Chi tiết").
class AdminAuditExcelExporter {
  static const _categoryOrder = [
    'Quản lý đơn',
    'Bài đăng',
    'Người dùng',
  ];

  /// Tạo nhanh workbook XLSX 1 sheet từ danh sách các dòng dữ liệu thô.
  static Uint8List create(List<List<Object?>> rows) {
    final columnCount = rows.isEmpty
        ? 1
        : rows.fold<int>(1, (max, r) => r.length > max ? r.length : max);
    final xlRows = <List<_XlCell>>[];
    for (var r = 0; r < rows.length; r++) {
      final style = r == 0 ? _XlStyle.header : _XlStyle.normal;
      xlRows.add(rows[r].map((v) => _XlCell(v, style)).toList());
    }
    final sheet = _XlSheet(
      name: 'Sheet1',
      rows: xlRows,
      columnWidths: List<double>.filled(columnCount, 24),
      headerRow: rows.isNotEmpty ? 1 : null,
      filterLastRow: rows.length > 1 ? rows.length : null,
    );
    return _buildWorkbook([sheet]);
  }

  static Uint8List createReport({
    required String monthLabel,
    required String exportedAt,
    required String exportedBy,
    required List<AdminAuditExcelEntry> entries,
  }) {
    final sorted = [...entries]..sort((a, b) => b.time.compareTo(a.time));
    final sheets = [
      _buildSummarySheet(monthLabel, exportedAt, exportedBy, sorted),
      _buildDetailSheet(monthLabel, sorted),
    ];
    return _buildWorkbook(sheets);
  }

  // ───────────────────────── Sheet Tổng hợp ─────────────────────────

  static _XlSheet _buildSummarySheet(
    String monthLabel,
    String exportedAt,
    String exportedBy,
    List<AdminAuditExcelEntry> entries,
  ) {
    final rows = <List<_XlCell>>[];
    final merges = <String>[];

    rows.add([_XlCell('BÁO CÁO HOẠT ĐỘNG ADMIN - THÁNG $monthLabel', _XlStyle.title)]);
    merges.add('A1:C1');
    rows.add([
      _XlCell('Xuất lúc $exportedAt • Người xuất: $exportedBy', _XlStyle.note),
    ]);
    merges.add('A2:C2');
    rows.add([]);

    // 1. Theo danh mục
    rows.add(const [
      _XlCell('Danh mục', _XlStyle.header),
      _XlCell('Số thao tác', _XlStyle.header),
      _XlCell('Tổng tiền (đ)', _XlStyle.header),
    ]);
    final categories = [..._categoryOrder];
    if (entries.any((e) => !_categoryOrder.contains(e.category))) {
      categories.add('Khác');
    }
    var totalCount = 0;
    num totalAmount = 0;
    for (final category in categories) {
      final items = entries.where((e) {
        return category == 'Khác'
            ? !_categoryOrder.contains(e.category)
            : e.category == category;
      }).toList();
      final amount = _sumAmount(items);
      totalCount += items.length;
      totalAmount += amount;
      rows.add([
        _XlCell(category, _XlStyle.cell),
        _XlCell(items.length, _XlStyle.center),
        _XlCell(amount, _XlStyle.money),
      ]);
    }
    rows.add([
      const _XlCell('Tổng cộng', _XlStyle.section),
      _XlCell(totalCount, _XlStyle.centerTotal),
      _XlCell(totalAmount, _XlStyle.moneyTotal),
    ]);
    rows.add([]);

    // 2. Thống kê tài chính (theo tên thao tác)
    rows.add(const [
      _XlCell('Thống kê tài chính', _XlStyle.header),
      _XlCell('Số giao dịch', _XlStyle.header),
      _XlCell('Số tiền (đ)', _XlStyle.header),
    ]);
    final financeGroups = <String, bool Function(String)>{
      'Giải ngân cho chủ trọ': (a) => a.contains('giải ngân'),
      'Bồi thường đơn hủy cho chủ trọ': (a) => a.contains('bồi thường'),
      'Hoàn tiền đơn hủy cho người thuê': (a) => a.contains('hoàn tiền'),
    };
    for (final group in financeGroups.entries) {
      final items = entries
          .where((e) => e.amount != null && group.value(e.action.toLowerCase()))
          .toList();
      rows.add([
        _XlCell(group.key, _XlStyle.cell),
        _XlCell(items.length, _XlStyle.center),
        _XlCell(_sumAmount(items), _XlStyle.money),
      ]);
    }
    rows.add([]);

    // 3. Theo người thực hiện
    rows.add(const [
      _XlCell('Người thực hiện', _XlStyle.header),
      _XlCell('Số thao tác', _XlStyle.header),
      _XlCell('Thao tác gần nhất', _XlStyle.header),
    ]);
    final byPerformer = <String, List<AdminAuditExcelEntry>>{};
    for (final e in entries) {
      byPerformer.putIfAbsent(e.performer, () => []).add(e);
    }
    final performers = byPerformer.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    for (final p in performers) {
      final latest = p.value
          .map((e) => e.time)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      rows.add([
        _XlCell(p.key, _XlStyle.cell),
        _XlCell(p.value.length, _XlStyle.center),
        _XlCell(DateFormat('dd/MM/yyyy HH:mm').format(latest), _XlStyle.center),
      ]);
    }

    return _XlSheet(
      name: 'Tổng hợp',
      rows: rows,
      columnWidths: const [38, 18, 24],
      merges: merges,
    );
  }

  // ───────────────────────── Sheet Chi tiết ─────────────────────────

  static _XlSheet _buildDetailSheet(
    String monthLabel,
    List<AdminAuditExcelEntry> entries,
  ) {
    final rows = <List<_XlCell>>[];
    rows.add([
      _XlCell('CHI TIẾT HOẠT ĐỘNG ADMIN - THÁNG $monthLabel', _XlStyle.title),
    ]);
    rows.add([]);
    const headerRow = 3;
    rows.add(const [
      _XlCell('STT', _XlStyle.header),
      _XlCell('Thời gian', _XlStyle.header),
      _XlCell('Người thực hiện', _XlStyle.header),
      _XlCell('Danh mục', _XlStyle.header),
      _XlCell('Thao tác', _XlStyle.header),
      _XlCell('Mã đơn / Đối tượng', _XlStyle.header),
      _XlCell('Chi tiết', _XlStyle.header),
      _XlCell('Số tiền (đ)', _XlStyle.header),
      _XlCell('Mã nhật ký', _XlStyle.header),
    ]);

    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      rows.add([
        _XlCell(i + 1, _XlStyle.center),
        _XlCell(DateFormat('dd/MM/yyyy HH:mm:ss').format(e.time), _XlStyle.cell),
        _XlCell(e.performer, _XlStyle.cell),
        _XlCell(e.category, _XlStyle.cell),
        _XlCell(e.action, _XlStyle.cell),
        _XlCell(e.target, _XlStyle.cell),
        _XlCell(e.detail, _XlStyle.cell),
        _XlCell(e.amount ?? '', _XlStyle.money),
        _XlCell(e.id, _XlStyle.cell),
      ]);
    }
    final lastDataRow = headerRow + entries.length;

    rows.add([
      const _XlCell('', _XlStyle.section),
      const _XlCell('', _XlStyle.section),
      const _XlCell('', _XlStyle.section),
      const _XlCell('', _XlStyle.section),
      const _XlCell('', _XlStyle.section),
      const _XlCell('', _XlStyle.section),
      const _XlCell('Tổng cộng', _XlStyle.section),
      _XlCell(_sumAmount(entries), _XlStyle.moneyTotal),
      const _XlCell('', _XlStyle.section),
    ]);

    return _XlSheet(
      name: 'Chi tiết',
      rows: rows,
      columnWidths: const [6, 20, 20, 16, 34, 26, 64, 16, 28],
      merges: const ['A1:I1'],
      headerRow: headerRow,
      filterLastRow: lastDataRow,
    );
  }

  static num _sumAmount(Iterable<AdminAuditExcelEntry> items) {
    num total = 0;
    for (final e in items) {
      final amount = e.amount;
      if (amount != null && amount.isFinite) total += amount;
    }
    return total;
  }

  // ───────────────────────── Ghi file xlsx ─────────────────────────

  static Uint8List _buildWorkbook(List<_XlSheet> sheets) {
    final archive = Archive();

    final sheetOverrides = StringBuffer();
    final workbookSheets = StringBuffer();
    final workbookRels = StringBuffer();
    for (var i = 0; i < sheets.length; i++) {
      final n = i + 1;
      sheetOverrides.write(
        '<Override PartName="/xl/worksheets/sheet$n.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
      );
      workbookSheets.write(
        '<sheet name="${_escapeXml(sheets[i].name)}" sheetId="$n" r:id="rId$n"/>',
      );
      workbookRels.write(
        '<Relationship Id="rId$n" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$n.xml"/>',
      );
    }
    final stylesRel = sheets.length + 1;
    workbookRels.write(
      '<Relationship Id="rId$stylesRel" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>',
    );

    archive
      ..addFile(
        _archiveFile(
          '[Content_Types].xml',
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
$sheetOverrides</Types>''',
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
<sheets>$workbookSheets</sheets>
</workbook>''',
        ),
      )
      ..addFile(
        _archiveFile(
          'xl/_rels/workbook.xml.rels',
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
$workbookRels</Relationships>''',
        ),
      )
      ..addFile(_archiveFile('xl/styles.xml', _stylesXml));

    for (var i = 0; i < sheets.length; i++) {
      archive.addFile(
        _archiveFile('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheets[i])),
      );
    }

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded ?? <int>[]);
  }

  static String _sheetXml(_XlSheet sheet) {
    final columnCount = sheet.columnWidths.length;
    final lastColumn = _columnName(columnCount);

    final cols = StringBuffer('<cols>');
    for (var i = 0; i < sheet.columnWidths.length; i++) {
      cols.write(
        '<col min="${i + 1}" max="${i + 1}" width="${sheet.columnWidths[i]}" customWidth="1"/>',
      );
    }
    cols.write('</cols>');

    final rowXml = StringBuffer();
    for (var r = 0; r < sheet.rows.length; r++) {
      final rowNumber = r + 1;
      final cells = sheet.rows[r];
      if (cells.isEmpty) {
        rowXml.write('<row r="$rowNumber"/>');
        continue;
      }
      rowXml.write('<row r="$rowNumber">');
      for (var c = 0; c < cells.length; c++) {
        rowXml.write(_cellXml(_columnName(c + 1), rowNumber, cells[c]));
      }
      rowXml.write('</row>');
    }

    final headerRow = sheet.headerRow;
    final view = headerRow == null
        ? '<sheetViews><sheetView workbookViewId="0" showGridLines="0"/></sheetViews>'
        : '<sheetViews><sheetView workbookViewId="0" showGridLines="0"><pane ySplit="$headerRow" topLeftCell="A${headerRow + 1}" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>';

    final filter = (headerRow != null &&
            sheet.filterLastRow != null &&
            sheet.filterLastRow! > headerRow)
        ? '<autoFilter ref="A$headerRow:$lastColumn${sheet.filterLastRow}"/>'
        : '';

    final merges = sheet.merges.isEmpty
        ? ''
        : '<mergeCells count="${sheet.merges.length}">${sheet.merges.map((m) => '<mergeCell ref="$m"/>').join()}</mergeCells>';

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
$view
$cols
<sheetData>$rowXml</sheetData>
$filter
$merges
</worksheet>''';
  }

  static String _cellXml(String column, int row, _XlCell cell) {
    final reference = '$column$row';
    final style = cell.style.index;
    final styleAttr = style == 0 ? '' : ' s="$style"';
    final value = cell.value;
    if (value is num && value.isFinite) {
      return '<c r="$reference"$styleAttr t="n"><v>$value</v></c>';
    }

    final text = _escapeXml(value?.toString() ?? '');
    return '<c r="$reference"$styleAttr t="inlineStr"><is><t xml:space="preserve">$text</t></is></c>';
  }

  // Thứ tự cellXfs phải khớp với thứ tự của enum _XlStyle.
  static const String _stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="5">
<font><sz val="11"/><name val="Calibri"/></font>
<font><b/><sz val="14"/><color rgb="FF101828"/><name val="Calibri"/></font>
<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>
<font><b/><sz val="11"/><name val="Calibri"/></font>
<font><i/><sz val="10"/><color rgb="FF667085"/><name val="Calibri"/></font>
</fonts>
<fills count="4">
<fill><patternFill patternType="none"/></fill>
<fill><patternFill patternType="gray125"/></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FF398FC0"/><bgColor indexed="64"/></patternFill></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FFEAF4FA"/><bgColor indexed="64"/></patternFill></fill>
</fills>
<borders count="2">
<border><left/><right/><top/><bottom/><diagonal/></border>
<border><left style="thin"><color rgb="FFBFD3E0"/></left><right style="thin"><color rgb="FFBFD3E0"/></right><top style="thin"><color rgb="FFBFD3E0"/></top><bottom style="thin"><color rgb="FFBFD3E0"/></bottom><diagonal/></border>
</borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="11">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
<xf numFmtId="0" fontId="2" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
<xf numFmtId="3" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" vertical="top"/></xf>
<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>
<xf numFmtId="3" fontId="3" fillId="3" borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" vertical="top"/></xf>
<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>
<xf numFmtId="0" fontId="4" fillId="0" borderId="0" xfId="0" applyFont="1"/>
<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="top"/></xf>
<xf numFmtId="0" fontId="3" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment vertical="top"/></xf>
<xf numFmtId="0" fontId="3" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="top"/></xf>
</cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>''';

  static ArchiveFile _archiveFile(String name, String contents) {
    final bytes = utf8.encode(contents);
    return ArchiveFile(name, bytes.length, bytes);
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
