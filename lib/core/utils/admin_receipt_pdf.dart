import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AdminReceiptPdf {
  static Future<Uint8List> build({
    required String title,
    required String amount,
    required String subtitle,
    required String receiptCode,
    required String sectionTitle,
    required List<MapEntry<String, String>> details,
    required List<String> tableHeaders,
    required List<List<String>> tableRows,
    required String totalLabel,
    required String totalAmount,
    required DateTime executedAt,
  }) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('lib/core/utils/admin_receipt_font.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('lib/core/utils/admin_receipt_font_bold.ttf'),
    );
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final green = PdfColor.fromHex('#027A48');
    final blue = PdfColor.fromHex('#155EEF');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(38, 40, 38, 44),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Text(
            'Biên lai nội bộ • $receiptCode • Trang ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'HOMESHARE',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: blue,
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              title.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Center(
            child: pw.Text(
              amount,
              style: pw.TextStyle(
                fontSize: 25,
                fontWeight: pw.FontWeight.bold,
                color: green,
              ),
            ),
          ),
          pw.Center(
            child: pw.Text(
              subtitle,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 6),
          ...details.map(
            (entry) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 145,
                    child: pw.Text(
                      entry.key,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      entry.value,
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            sectionTitle,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
            columnWidths: {
              for (var i = 0; i < tableHeaders.length; i++)
                i: pw.FlexColumnWidth(i == 0 ? 2 : 1),
            },
            children: [
              _tableRow(tableHeaders, header: true),
              ...tableRows.map((row) => _tableRow(row)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            color: PdfColor.fromHex('#ECFDF3'),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    totalLabel,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: green,
                    ),
                  ),
                ),
                pw.Text(
                  totalAmount,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: green,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Center(
            child: pw.Text(
              'Thời gian ghi nhận: ${_formatDate(executedAt)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  static pw.TableRow _tableRow(List<String> values, {bool header = false}) =>
      pw.TableRow(
        decoration: header
            ? pw.BoxDecoration(color: PdfColor.fromHex('#F2F4F7'))
            : null,
        children: values
            .asMap()
            .entries
            .map(
              (entry) => pw.Padding(
                padding: const pw.EdgeInsets.all(7),
                child: pw.Text(
                  entry.value,
                  textAlign: entry.key == 0
                      ? pw.TextAlign.left
                      : pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: header ? 8 : 8.5,
                    fontWeight: header || entry.key == 0
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                    color: header ? PdfColors.grey700 : PdfColors.grey900,
                  ),
                ),
              ),
            )
            .toList(),
      );

  static String _formatDate(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} - ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
