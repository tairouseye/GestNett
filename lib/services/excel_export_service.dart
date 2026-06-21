import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/client.dart';
import '../models/expense.dart';
import '../models/invoice.dart';
import '../models/market.dart';

class ExcelExportService {
  static final _fmt = DateFormat('dd/MM/yyyy');

  static Future<void> _share(Excel excel, String prefix) async {
    final bytes = excel.encode();
    if (bytes == null) return;
    final name = '${prefix}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
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

  static Future<void> exportInvoices(List<Invoice> invoices) async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Factures'];
    sheet.appendRow([
      TextCellValue('N°'), TextCellValue('Date'), TextCellValue('Échéance'),
      TextCellValue('Client'), TextCellValue('Marché'), TextCellValue('Type'),
      TextCellValue('Statut'), TextCellValue('Montant HT'), TextCellValue('Total TTC'),
    ]);
    for (final i in invoices) {
      sheet.appendRow([
        TextCellValue(i.numero),
        TextCellValue(_fmt.format(i.date)),
        TextCellValue(_fmt.format(i.echeance)),
        TextCellValue(i.clientNom ?? ''),
        TextCellValue(i.marketNumero ?? ''),
        TextCellValue(i.isProforma ? 'Proforma' : 'Définitive'),
        TextCellValue(i.statut.label),
        IntCellValue(i.montantHt.round()),
        IntCellValue(i.totalTtc.round()),
      ]);
    }
    await _share(excel, 'factures');
  }

  static Future<void> exportClients(List<Client> clients) async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Clients'];
    sheet.appendRow([
      TextCellValue('Nom / Société'), TextCellValue('Type'), TextCellValue('Contact'),
      TextCellValue('Téléphone'), TextCellValue('Email'), TextCellValue('Adresse'),
      TextCellValue('NINEA'),
    ]);
    for (final c in clients) {
      sheet.appendRow([
        TextCellValue(c.nom),
        TextCellValue(c.type != null ? c.typeLabel : ''),
        TextCellValue(c.contact ?? ''),
        TextCellValue(c.telephone ?? ''),
        TextCellValue(c.email ?? ''),
        TextCellValue(c.adresse ?? ''),
        TextCellValue(c.ninea ?? ''),
      ]);
    }
    await _share(excel, 'clients');
  }

  static Future<void> exportMarkets(List<Market> markets) async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Marches'];
    sheet.appendRow([
      TextCellValue('N°'), TextCellValue('Client'), TextCellValue('Statut'),
      TextCellValue('Début'), TextCellValue('Fin'), TextCellValue('Montant contrat'),
      TextCellValue('Description'),
    ]);
    for (final m in markets) {
      sheet.appendRow([
        TextCellValue(m.numero),
        TextCellValue(m.clientNom ?? ''),
        TextCellValue(m.statut.label),
        TextCellValue(m.dateDebut != null ? _fmt.format(m.dateDebut!) : ''),
        TextCellValue(m.dateFin != null ? _fmt.format(m.dateFin!) : ''),
        IntCellValue(m.montantTotal.round()),
        TextCellValue(m.description ?? ''),
      ]);
    }
    await _share(excel, 'marches');
  }

  static Future<void> exportExpenses(List<Expense> expenses) async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Depenses'];
    sheet.appendRow([
      TextCellValue('Date'), TextCellValue('Famille'), TextCellValue('Rubrique'),
      TextCellValue('Marché'), TextCellValue('Montant'), TextCellValue('Description'),
    ]);
    for (final e in expenses) {
      sheet.appendRow([
        TextCellValue(_fmt.format(e.date)),
        TextCellValue(e.type.famille.label),
        TextCellValue(e.type.label),
        TextCellValue(e.marketNumero ?? 'Frais général'),
        IntCellValue(e.montant.round()),
        TextCellValue(e.description ?? ''),
      ]);
    }
    await _share(excel, 'depenses');
  }
}
