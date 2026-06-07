import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/invoice.dart';
import '../models/company_settings.dart';
import '../features/invoices/invoice_wizard_data.dart';

class PdfService {
  PdfService._();

  // Couleurs D2SERVICES
  static const _darkGreen = PdfColor.fromInt(0xFF145221);
  static const _textBlack = PdfColor.fromInt(0xFF111111);
  static const _textGray  = PdfColor.fromInt(0xFF444444);
  static const _textBlue  = PdfColor.fromInt(0xFF1B4F8A);
  static const _textRed   = PdfColor.fromInt(0xFFCC0000);
  static const _borderCol = PdfColor.fromInt(0xFF111111);

  static final _numFmt = NumberFormat('#,##0', 'fr_FR');

  static String _formatDate(DateTime d) =>
      DateFormat('dd MMMM yyyy', 'fr_FR').format(d);

  /// Génère un PDF depuis une facture sauvegardée en base de données.
  static Future<Uint8List> generateFromInvoice(
    Invoice invoice, {
    CompanySettings? settings,
  }) async {
    final data = InvoiceWizardData(
      clientNom: invoice.clientNom ?? 'Client',
      clientAdresse: '',
      clientId: invoice.clientId,
      marketId: invoice.marketId,
      prestations: [
        PrestationLine(
          designation: 'Prestation de nettoyage',
          montant: invoice.montantHt,
        ),
      ],
      reductionPct: 0,
      applyTva: invoice.tvaPct > 0,
      date: invoice.date,
      numero: invoice.numero,
    );
    return generateInvoice(data, settings: settings);
  }

  /// Génère le PDF de la facture et retourne les bytes.
  static Future<Uint8List> generateInvoice(
    InvoiceWizardData data, {
    CompanySettings? settings,
  }) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
      ),
    );

    // Chargement des images : URL distante (settings) ou asset local (fallback)
    pw.ImageProvider? logoImage;
    pw.ImageProvider? cachetImage;

    if (settings?.logoUrl != null && settings!.logoUrl!.isNotEmpty) {
      try {
        final resp = await http.get(Uri.parse(settings.logoUrl!));
        if (resp.statusCode == 200) logoImage = pw.MemoryImage(resp.bodyBytes);
      } catch (_) {}
    }
    if (logoImage == null) {
      try {
        final bytes = await rootBundle.load('assets/images/logo.png');
        logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {}
    }

    if (settings?.signatureUrl != null && settings!.signatureUrl!.isNotEmpty) {
      try {
        final resp = await http.get(Uri.parse(settings.signatureUrl!));
        if (resp.statusCode == 200) cachetImage = pw.MemoryImage(resp.bodyBytes);
      } catch (_) {}
    }
    if (cachetImage == null) {
      try {
        final bytes = await rootBundle.load('assets/images/Signature.png');
        cachetImage = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {}
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 30),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── 1. EN-TÊTE ─────────────────────────────────────────────────
            _buildHeader(logoImage, settings),
            pw.SizedBox(height: 14),

            // ── 2. BLOC DATE / CLIENT / ADRESSE ────────────────────────────
            _buildMetaBlock(data),
            pw.SizedBox(height: 14),

            // ── 3. TITRE FACTURE ────────────────────────────────────────────
            _buildTitle(data.numero),
            pw.SizedBox(height: 12),

            // ── 4. TABLEAU ─────────────────────────────────────────────────
            _buildTable(data),
            pw.SizedBox(height: 16),

            // ── 5. ARRÊTÉE ─────────────────────────────────────────────────
            _buildArretee(data),
            pw.Spacer(),

            // ── 6. SIGNATURE ───────────────────────────────────────────────
            _buildSignature(cachetImage),
            pw.SizedBox(height: 16),

            // ── 7. PIED DE PAGE LÉGAL ───────────────────────────────────────
            _buildFooter(settings),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // EN-TÊTE : logo + infos société (dynamique si settings, sinon D2SERVICES)
  // ─────────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(
      pw.ImageProvider? logo, CompanySettings? settings) {
    final name    = settings?.companyName.isNotEmpty == true ? settings!.companyName : 'D2SERVICES';
    final slogan  = settings?.slogan ?? 'SOLUTIONS PROFESSIONNELLES DE NETTOYAGE, BTP ET SERVICES ASSOCIÉS';
    final desc    = settings?.description ?? 'Entreprise de nettoyage professionnel, industriel, BTP, Placement de personnel,\nDéco, Phytosanitaire & services connexes.';
    final adresse = settings?.adresse ?? 'Ouakam Tagolou – Dakar, Sénégal';
    final tel     = settings?.telephone ?? '(+221) 77 562 03 50';
    final tel2    = settings?.telephone2;
    final email   = settings?.email ?? 'd2services2018net@gmail.com';
    final telLine = tel2 != null && tel2.isNotEmpty ? 'Tel: $tel / $tel2' : 'Tel: $tel';
    final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : name;

    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo (ou placeholder initiales)
            if (logo != null)
              pw.Container(
                width: 70,
                height: 70,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              )
            else
              pw.Container(
                width: 70,
                height: 70,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                      color: const PdfColor.fromInt(0xFFCCCCCC)),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Center(
                  child: pw.Text(initials,
                      style: pw.TextStyle(
                          font: pw.Font.helveticaBold(),
                          fontSize: 22,
                          color: _darkGreen)),
                ),
              ),
            pw.SizedBox(width: 10),

            // Infos société
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(name,
                      style: pw.TextStyle(
                          font: pw.Font.helveticaBold(),
                          fontSize: 13,
                          color: _textBlack)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    slogan,
                    style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: 7.5,
                        color: _textBlue),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    desc,
                    style: pw.TextStyle(fontSize: 7, color: _textGray),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(adresse, style: pw.TextStyle(fontSize: 7, color: _textGray)),
                  pw.Text('$telLine   Email: $email', style: pw.TextStyle(fontSize: 7, color: _textGray)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1.5, color: _textBlack),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BLOC META : Date / Doit / Adresse (aligné à droite)
  // ─────────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildMetaBlock(InvoiceWizardData data) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _metaRow('Date', _formatDate(data.date)),
          _metaRow('Doit', data.clientNom),
          if (data.clientAdresse.trim().isNotEmpty)
            _metaRow('Adresse', data.clientAdresse),
        ],
      ),
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(
            text: '$label : ',
            style: pw.TextStyle(
                font: pw.Font.helveticaBold(),
                fontSize: 10,
                decoration: pw.TextDecoration.underline),
          ),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(
                font: pw.Font.helveticaBold(), fontSize: 10),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TITRE FACTURE
  // ─────────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildTitle(String numero) {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text(
            'FACTURE',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 18,
              decoration: pw.TextDecoration.underline,
              color: _textBlack,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'N° $numero',
            style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 9,
                color: _textGray),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TABLEAU PRESTATIONS
  // ─────────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildTable(InvoiceWizardData data) {
    final rows = <pw.TableRow>[];

    // En-tête
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.white),
      children: [
        _cell('Désignation', bold: true, center: true),
        _cell('Montant', bold: true, center: true, width: 120),
      ],
    ));

    // Lignes prestations
    for (final p in data.prestations) {
      rows.add(pw.TableRow(children: [
        _cell(p.designation),
        _cell(_numFmt.format(p.montant.round()), right: true, width: 120),
      ]));
    }

    // Sous-total (si plusieurs prestations)
    if (data.prestations.length > 1) {
      rows.add(pw.TableRow(
        decoration:
            const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0F0F0)),
        children: [
          _cell('Sous-total', bold: true, center: true),
          _cell(_numFmt.format(data.sousTotal.round()),
              bold: true, right: true, width: 120),
        ],
      ));
    }

    // Réduction
    if (data.reductionPct > 0) {
      rows.add(pw.TableRow(children: [
        _cell('Réduction (${data.reductionPct.toStringAsFixed(0)}%)',
            color: _textRed),
        _cell('- ${_numFmt.format(data.montantReduction.round())}',
            color: _textRed, right: true, width: 120),
      ]));
    }

    // TVA
    if (data.applyTva) {
      rows.add(pw.TableRow(children: [
        _cell('TVA (18%)'),
        _cell(_numFmt.format(data.montantTva.round()),
            right: true, width: 120),
      ]));
    }

    // Total
    rows.add(pw.TableRow(
      decoration:
          const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF6FDF8)),
      children: [
        _cell('Total', bold: true, center: true),
        _cell(_numFmt.format(data.totalTTC.round()),
            bold: true, right: true, width: 120),
      ],
    ));

    return pw.Table(
      border: pw.TableBorder.all(color: _borderCol, width: 0.8),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FixedColumnWidth(120),
      },
      children: rows,
    );
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    bool center = false,
    bool right = false,
    double? width,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        textAlign: center
            ? pw.TextAlign.center
            : right
                ? pw.TextAlign.right
                : pw.TextAlign.left,
        style: pw.TextStyle(
          font: bold ? pw.Font.helveticaBold() : pw.Font.helvetica(),
          fontSize: 10,
          color: color ?? _textBlack,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ARRÊTÉE
  // ─────────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildArretee(InvoiceWizardData data) {
    return pw.RichText(
      text: pw.TextSpan(children: [
        pw.TextSpan(
          text: 'Arrêtée la présente facture à la somme de : ',
          style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 10.5),
        ),
        pw.TextSpan(
          text: data.totalEnLettres,
          style: pw.TextStyle(
              font: pw.Font.helveticaBold(), fontSize: 10.5),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PIED DE PAGE LÉGAL : NINEA | RCCM | Compte
  // ─────────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(CompanySettings? settings) {
    final parts   = <String>[];
    final ninea   = settings?.ninea;
    final rccm    = settings?.rccm;
    final iban    = settings?.iban;
    final banque  = settings?.nomBanque;

    if (ninea  != null && ninea.isNotEmpty)  parts.add('NINEA : $ninea');
    if (rccm   != null && rccm.isNotEmpty)   parts.add('RCCM : $rccm');

    if (banque != null && banque.isNotEmpty && iban != null && iban.isNotEmpty) {
      parts.add('$banque – IBAN : $iban');
    } else if (iban != null && iban.isNotEmpty) {
      parts.add('IBAN : $iban');
    } else if (banque != null && banque.isNotEmpty) {
      parts.add(banque);
    }

    if (parts.isEmpty) return pw.SizedBox.shrink();

    return pw.Column(children: [
      pw.Divider(thickness: 0.6, color: const PdfColor.fromInt(0xFF888888)),
      pw.SizedBox(height: 4),
      pw.Center(
        child: pw.Text(
          parts.join('   |   '),
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 7.5,
            color: _textGray,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SIGNATURE / CACHET (bas à droite)
  // ─────────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildSignature(pw.ImageProvider? cachetImage) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            'La Responsable',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 11,
              decoration: pw.TextDecoration.underline,
            ),
          ),
          pw.SizedBox(height: 8),
          if (cachetImage != null)
            pw.Container(
              width: 160,
              height: 80,
              child: pw.Image(cachetImage, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              width: 160,
              height: 70,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                    color: const PdfColor.fromInt(0xFFCCCCCC),
                    style: pw.BorderStyle.dashed),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Center(
                child: pw.Text('Cachet + Signature',
                    style: pw.TextStyle(
                        fontSize: 9,
                        color: const PdfColor.fromInt(0xFF999999))),
              ),
            ),
        ],
      ),
    );
  }
}
