import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/invoice.dart';
import '../../models/payment.dart';
import '../../models/company_settings.dart';
import '../../services/invoice_service.dart';
import '../../services/payment_service.dart';
import '../../services/pdf_service.dart';
import '../../services/company_settings_service.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  Invoice? _invoice;
  List<Payment> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final inv = await InvoiceService().getById(widget.invoiceId);
    final pays = inv != null
        ? await PaymentService().getByInvoice(widget.invoiceId)
        : <Payment>[];
    if (mounted) setState(() { _invoice = inv; _payments = pays; _loading = false; });
  }

  double get _totalPaid =>
      _payments.fold(0.0, (s, p) => s + p.montant);

  double get _restant =>
      (_invoice?.totalTtc ?? 0) - _totalPaid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.g50,
      appBar: AppBar(
        title: Text(_invoice?.numero ?? 'Facture'),
        actions: [
          if (_invoice?.pdfUrl != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Voir PDF',
              onPressed: () async => launchUrl(
                Uri.parse(_invoice!.pdfUrl!),
                mode: LaunchMode.platformDefault,
              ),
            ),
          if (_invoice != null)
            PopupMenuButton<InvoiceStatut>(
              icon: const Icon(Icons.more_vert),
              onSelected: (s) async {
                await InvoiceService().updateStatut(_invoice!.id, s);
                if (mounted) await _load();
              },
              // « Soldée » et « Acompte » découlent des paiements enregistrés :
              // ils ne sont pas modifiables manuellement.
              itemBuilder: (_) => const [
                InvoiceStatut.brouillon,
                InvoiceStatut.emise,
                InvoiceStatut.annulee,
              ].map((s) => PopupMenuItem(value: s, child: Text(s.label))).toList(),
            ),
        ],
      ),
      floatingActionButton: _invoice != null && _restant > 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddPayment(context),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Enregistrer paiement'),
              backgroundColor: AppColors.g700,
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoice == null
              ? const Center(child: Text('Facture introuvable'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _InvoiceInfoCard(invoice: _invoice!),
                      if (_invoice!.isProforma) ...[
                        const SizedBox(height: 12),
                        _ConvertProformaCard(
                          invoice: _invoice!,
                          onConverted: _load,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _PdfActionsCard(invoice: _invoice!),
                      const SizedBox(height: 12),
                      _BilanCard(
                        totalTtc: _invoice!.totalTtc,
                        totalPaid: _totalPaid,
                        restant: _restant,
                      ),
                      const SizedBox(height: 12),
                      _PaymentsSection(
                        payments: _payments,
                        onDelete: (id) async {
                          await PaymentService().delete(id);
                          _load();
                        },
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  Future<void> _showAddPayment(BuildContext context) async {
    final created = await showModalBottomSheet<Payment>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPaymentSheet(
        invoice: _invoice!,
        restant: _restant,
      ),
    );
    if (created != null) {
      await _load();
      if (mounted) await _proposeRecu(created);
    }
  }

  Future<void> _proposeRecu(Payment payment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paiement enregistré ✓'),
        content: const Text('Voulez-vous générer un reçu de paiement (PDF) à envoyer au client ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Plus tard')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.receipt_outlined, size: 18),
            label: const Text('Reçu PDF'),
          ),
        ],
      ),
    );
    if (ok != true || _invoice == null) return;
    try {
      final settings = await CompanySettingsService.getMySettings();
      final bytes = await PdfService.generateRecu(
        payment: payment,
        invoice: _invoice!,
        totalPaye: _totalPaid,
        settings: settings,
      );
      await Printing.sharePdf(bytes: bytes, filename: 'recu-${_invoice!.numero}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur génération reçu : $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }
}

// ── Info carte facture ────────────────────────────────────────────────────────

class _InvoiceInfoCard extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceInfoCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (invoice.statut) {
      InvoiceStatut.payee        => AppColors.g600,
      InvoiceStatut.payeePartiel => AppColors.gold,
      InvoiceStatut.emise        => AppColors.orange,
      InvoiceStatut.annulee      => AppColors.red,
      InvoiceStatut.brouillon    => AppColors.s400,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(invoice.clientNom ?? 'Client',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (invoice.isProforma)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B4F8A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1B4F8A).withValues(alpha: 0.3)),
                    ),
                    child: const Text('PROFORMA',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B4F8A))),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(invoice.statut.label,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
            const Divider(height: 20),
            _Row('Numéro', invoice.numero),
            _Row('Date', Formatters.date(invoice.date)),
            _Row('Montant HT', Formatters.fcfa(invoice.montantHt)),
            if (invoice.tvaPct > 0)
              _Row('TVA (${invoice.tvaPct.toStringAsFixed(0)}%)',
                  Formatters.fcfa(invoice.montantTva)),
            _Row('Total TTC', Formatters.fcfa(invoice.totalTtc),
                bold: true),
          ],
        ),
      ),
    );
  }
}

// ── Conversion Proforma → Définitive ─────────────────────────────────────────

class _ConvertProformaCard extends StatefulWidget {
  final Invoice invoice;
  final VoidCallback onConverted;
  const _ConvertProformaCard({required this.invoice, required this.onConverted});

  @override
  State<_ConvertProformaCard> createState() => _ConvertProformaCardState();
}

class _ConvertProformaCardState extends State<_ConvertProformaCard> {
  bool _loading = false;

  Future<void> _convert() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer en facture définitive ?'),
        content: const Text(
            'Cette action est irréversible. La proforma deviendra une facture définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.g700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await InvoiceService().convertirEnDefinitive(widget.invoice.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facture convertie en définitive'),
              backgroundColor: AppColors.g600),
        );
        widget.onConverted();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFEEF3FA),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        const Icon(Icons.info_outline, color: Color(0xFF1B4F8A), size: 20),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Cette facture est une proforma (avant-projet).',
            style: TextStyle(fontSize: 12, color: Color(0xFF1B4F8A)),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.g700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
          ),
          onPressed: _loading ? null : _convert,
          child: _loading
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Confirmer en définitive'),
        ),
      ]),
    ),
  );
}

// ── Actions PDF ───────────────────────────────────────────────────────────────

class _PdfActionsCard extends StatefulWidget {
  final Invoice invoice;
  const _PdfActionsCard({required this.invoice});

  @override
  State<_PdfActionsCard> createState() => _PdfActionsCardState();
}

class _PdfActionsCardState extends State<_PdfActionsCard> {
  bool _busy = false;
  CompanySettings? _settings;

  Invoice get invoice => widget.invoice;

  @override
  void initState() {
    super.initState();
    CompanySettingsService.getMySettings().then((s) {
      if (mounted) setState(() => _settings = s);
    });
  }

  String get _waMsg {
    final name = _settings?.companyName.isNotEmpty == true
        ? _settings!.companyName
        : 'GesPro';
    final tel = _settings?.telephone;
    return 'Bonjour,\n\nVeuillez trouver ci-joint votre facture $name.\n\n'
        '📄 Facture N° : ${invoice.numero}\n'
        '👤 Client : ${invoice.clientNom ?? ''}\n'
        '💰 Total TTC : ${Formatters.fcfa(invoice.totalTtc)}\n\n'
        'Cordialement,\n$name'
        '${tel != null && tel.isNotEmpty ? '\n📞 $tel' : ''}';
  }

  Future<bool> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
      return true;
    }
    return false;
  }

  Future<void> _withBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try { await action(); } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _openPdf(BuildContext context) => _withBusy(() async {
    final bytes = await PdfService.generateFromInvoice(invoice, settings: _settings);
    await Printing.sharePdf(bytes: bytes, filename: '${invoice.numero}.pdf');
  });

  Future<void> _shareWhatsApp(BuildContext context) => _withBusy(() async {
    final waUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_waMsg)}');
    await _launch(waUri);
  });

  Future<void> _shareEmail(BuildContext context) => _withBusy(() async {
    final subject = Uri.encodeComponent('Facture – ${invoice.numero}');
    final body    = Uri.encodeComponent(_waMsg);
    if (!await _launch(Uri.parse('mailto:?subject=$subject&body=$body'))) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun client mail configuré')),
        );
      }
    }
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.picture_as_pdf_outlined,
                    color: AppColors.red, size: 18),
                const SizedBox(width: 6),
                const Text('Document PDF',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                if (_busy)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.open_in_new_outlined,
                    label: 'Voir PDF',
                    color: AppColors.g700,
                    enabled: !_busy,
                    onTap: () => _openPdf(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.chat_outlined,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    enabled: !_busy,
                    onTap: () => _shareWhatsApp(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    color: AppColors.blue,
                    enabled: !_busy,
                    onTap: () => _shareEmail(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: enabled
            ? color.withValues(alpha: 0.1)
            : AppColors.s100.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.3)
                : Colors.transparent),
      ),
      child: Column(
        children: [
          Icon(icon,
              color: enabled ? color : AppColors.s300, size: 20),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: enabled ? color : AppColors.s300)),
        ],
      ),
    ),
  );
}

// ── Bilan paiements ───────────────────────────────────────────────────────────

class _BilanCard extends StatelessWidget {
  final double totalTtc, totalPaid, restant;
  const _BilanCard({
    required this.totalTtc,
    required this.totalPaid,
    required this.restant,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalTtc > 0 ? (totalPaid / totalTtc).clamp(0.0, 1.0) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Suivi paiement',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: AppColors.g100,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.g600),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _BilanChip('Encaissé', Formatters.fcfa(totalPaid),
                    AppColors.g600),
                const SizedBox(width: 8),
                _BilanChip('Restant', Formatters.fcfa(restant),
                    restant > 0 ? AppColors.orange : AppColors.g600),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BilanChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _BilanChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    ),
  );
}

// ── Liste paiements ───────────────────────────────────────────────────────────

class _PaymentsSection extends StatelessWidget {
  final List<Payment> payments;
  final void Function(String id) onDelete;
  const _PaymentsSection(
      {required this.payments, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Historique des paiements (${payments.length})',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        if (payments.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined,
                      color: AppColors.s300, size: 28),
                  const SizedBox(width: 12),
                  const Text('Aucun paiement enregistré',
                      style: TextStyle(color: AppColors.s400)),
                ],
              ),
            ),
          )
        else
          ...payments.map((p) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.g100,
                child: const Icon(Icons.check_circle_outline,
                    color: AppColors.g600, size: 20),
              ),
              title: Text(Formatters.fcfa(p.montant),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.g700)),
              subtitle: Text(
                '${p.type.label} · ${DateFormat('dd MMM yyyy', 'fr_FR').format(p.date)}'
                '${p.notes != null ? '\n${p.notes}' : ''}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.red, size: 18),
                onPressed: () => _confirmDelete(context, p.id),
              ),
              isThreeLine: p.notes != null,
            ),
          )),
      ],
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce paiement ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () { Navigator.pop(dialogContext); onDelete(id); },
              child: const Text('Supprimer',
                  style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
  }
}

// ── Formulaire paiement ───────────────────────────────────────────────────────

class _AddPaymentSheet extends StatefulWidget {
  final Invoice invoice;
  final double restant;
  const _AddPaymentSheet(
      {required this.invoice, required this.restant});

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  final _montantCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  PaymentType _type = PaymentType.partiel;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pré-remplir avec le restant
    _montantCtrl.text = widget.restant.round().toString();
    if (widget.restant >= widget.invoice.totalTtc) {
      _type = PaymentType.totalite;
    }
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final montant = double.tryParse(
        _montantCtrl.text.replaceAll(' ', '').replaceAll(',', ''));
    if (montant == null || montant <= 0) {
      setState(() => _error = 'Montant invalide');
      return;
    }
    if (montant > widget.restant + 1) {
      setState(() => _error =
          'Montant supérieur au restant (${Formatters.fcfa(widget.restant)})');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final created = await PaymentService().add(Payment(
        id: '',
        invoiceId: widget.invoice.id,
        montant: montant,
        date: _date,
        type: _type,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: DateTime.now(),
      ));
      // Mettre à jour le statut selon le montant payé
      if (montant >= widget.restant - 1) {
        await InvoiceService()
            .updateStatut(widget.invoice.id, InvoiceStatut.payee);
      } else {
        await InvoiceService()
            .updateStatut(widget.invoice.id, InvoiceStatut.payeePartiel);
      }
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Enregistrer un paiement',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Type de paiement
            Row(
              children: PaymentType.values.map((t) {
                final sel = _type == t;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.g700 : AppColors.g50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: sel
                                ? AppColors.g700
                                : AppColors.g100),
                      ),
                      child: Text(t.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sel
                                  ? Colors.white
                                  : AppColors.g700)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Montant
            TextField(
              controller: _montantCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant (FCFA)',
                prefixIcon: const Icon(Icons.payments_outlined),
                suffixText: 'FCFA',
                helperText:
                    'Restant : ${Formatters.fcfa(widget.restant)}',
              ),
            ),
            const SizedBox(height: 10),

            // Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined,
                  color: AppColors.g600, size: 20),
              title: Text(
                DateFormat('dd MMMM yyyy', 'fr_FR').format(_date),
                style: const TextStyle(fontSize: 13),
              ),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _date = d);
              },
            ),

            // Notes
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optionnel)',
                prefixIcon: Icon(Icons.notes_outlined),
                hintText: 'Mode de paiement, référence...',
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      const TextStyle(color: AppColors.red, fontSize: 12)),
            ],

            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_saving ? 'Enregistrement...' : 'Confirmer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.s400, fontSize: 12)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontWeight: bold
                      ? FontWeight.bold
                      : FontWeight.w600,
                  fontSize: 13,
                  color: bold ? AppColors.g700 : null)),
        ),
      ],
    ),
  );
}
