import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../services/invoice_service.dart';

class UnpaidScreen extends StatefulWidget {
  const UnpaidScreen({super.key});

  @override
  State<UnpaidScreen> createState() => _UnpaidScreenState();
}

class _UnpaidScreenState extends State<UnpaidScreen> {
  List<UnpaidInvoice> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await InvoiceService().getUnpaid();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  double get _totalRestant => _items.fold(0.0, (s, e) => s + e.restant);

  Future<void> _relancer(UnpaidInvoice u) async {
    final tel = (u.invoice.clientTelephone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final msg =
        'Bonjour ${u.invoice.clientNom ?? ''},\n\n'
        'Nous revenons vers vous concernant la facture N° ${u.invoice.numero} '
        'du ${DateFormat('dd/MM/yyyy', 'fr_FR').format(u.invoice.date)}.\n\n'
        '💰 Montant restant dû : ${Formatters.fcfa(u.restant)}\n\n'
        'Merci de bien vouloir procéder au règlement dès que possible.\n'
        'Cordialement.';
    final url = tel.isNotEmpty
        ? 'https://wa.me/$tel?text=${Uri.encodeComponent(msg)}'
        : 'https://wa.me/?text=${Uri.encodeComponent(msg)}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.g50,
      appBar: AppBar(title: const Text('Impayés & relances')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const _EmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _TotalCard(total: _totalRestant, count: _items.length),
                      const SizedBox(height: 12),
                      ..._items.map((u) => _UnpaidTile(
                            item: u,
                            onTap: () async {
                              await context.push('/invoices/${u.invoice.id}');
                              _load();
                            },
                            onRelancer: () => _relancer(u),
                          )),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  final int count;
  const _TotalCard({required this.total, required this.count});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_bottom_outlined, color: AppColors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count facture${count > 1 ? 's' : ''} en attente de paiement',
                      style: const TextStyle(fontSize: 12, color: AppColors.s500)),
                  const SizedBox(height: 2),
                  Text('Total à encaisser : ${Formatters.fcfa(total)}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.orange)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _UnpaidTile extends StatelessWidget {
  final UnpaidInvoice item;
  final VoidCallback onTap;
  final VoidCallback onRelancer;
  const _UnpaidTile({required this.item, required this.onTap, required this.onRelancer});

  @override
  Widget build(BuildContext context) {
    final retard = item.joursRetard;
    final enRetard = retard > 30;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.invoice.clientNom ?? 'Client',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(item.invoice.numero,
                            style: const TextStyle(fontSize: 11, color: AppColors.s400)),
                      ],
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Formatters.fcfa(item.restant),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.orange)),
                    if (item.paid > 0)
                      Text('payé ${Formatters.fcfa(item.paid)}',
                          style: const TextStyle(fontSize: 10, color: AppColors.g600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule,
                    size: 13, color: enRetard ? AppColors.red : AppColors.s400),
                const SizedBox(width: 4),
                Text(
                  enRetard ? 'En retard de $retard jours' : 'Émise il y a $retard jours',
                  style: TextStyle(
                      fontSize: 11,
                      color: enRetard ? AppColors.red : AppColors.s400,
                      fontWeight: enRetard ? FontWeight.w600 : FontWeight.normal),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onRelancer,
                  icon: const Icon(Icons.chat_outlined, size: 16),
                  label: const Text('Relancer', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.g700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle_outline, size: 56, color: AppColors.g400),
            SizedBox(height: 12),
            Text('Aucune facture impayée 🎉',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Toutes vos factures définitives sont soldées.',
                style: TextStyle(fontSize: 12, color: AppColors.s400)),
          ],
        ),
      );
}
