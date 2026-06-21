import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/invoice.dart';

class ExcelExportService {
  /// Exporte une liste de factures en .xlsx et ouvre le partage / téléchargement.
  static Future<void> exportInvoices(List<Invoice> invoices) async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Factures'];
    final fmt = DateFormat('dd/MM/yyyy');

    sheet.appendRow([
      TextCellValue('N°'),
      TextCellValue('Date'),
      TextCellValue('Échéance'),
      TextCellValue('Client'),
      TextCellValue('Marché'),
      TextCellValue('Type'),
      TextCellValue('Statut'),
      TextCellValue('Montant HT'),
      TextCellValue('Total TTC'),
    ]);

    for (final i in invoices) {
      sheet.appendRow([
        TextCellValue(i.numero),
        TextCellValue(fmt.format(i.date)),
        TextCellValue(fmt.format(i.echeance)),
        TextCellValue(i.clientNom ?? ''),
        TextCellValue(i.marketNumero ?? ''),
        TextCellValue(i.isProforma ? 'Proforma' : 'Définitive'),
        TextCellValue(i.statut.label),
        IntCellValue(i.montantHt.round()),
        IntCellValue(i.totalTtc.round()),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    final name = 'factures_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(bytes),
          name: name,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      fileNameOverrides: [name],
    );
  }
}
