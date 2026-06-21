import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/invoice.dart';
import '../../providers/invoices_stats_provider.dart';

class InvoicesDashboardScreen extends ConsumerWidget {
  const InvoicesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(invoicesStatsProvider);
    return Scaffold(
      backgroundColor: AppColors.g50,
      appBar: AppBar(
        title: const Text('Tableau de bord Factures'),
        backgroundColor: AppColors.g700,
        foregroundColor: Colors.white,
      ),
      body: stats.when(
        data: (s) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(invoicesStatsProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                _Kpi('Facturé', Formatters.fcfa(s.caFacture), Icons.receipt_long_outlined, AppColors.blue),
                const SizedBox(width: 8),
                _Kpi('Encaissé', Formatters.fcfa(s.encaisse), Icons.account_balance_wallet_outlined, AppColors.g600),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _Kpi('Reste à encaisser', Formatters.fcfa(s.reste), Icons.hourglass_bottom_outlined,
                    s.reste > 0 ? AppColors.orange : AppColors.g600),
                const SizedBox(width: 8),
                _Kpi('Taux de recouvrement', '${(s.tauxRecouvrement * 100).toStringAsFixed(0)} %',
                    Icons.percent, AppColors.g700),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _Kpi('En retard', '${s.nbEnRetard}', Icons.warning_amber_outlined, AppColors.red),
                const SizedBox(width: 8),
                _Kpi('Montant en retard', Formatters.fcfa(s.montantEnRetard), Icons.error_outline, AppColors.red),
              ]),
              const SizedBox(height: 16),

              const Text('Répartition (factures définitives)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _statLine('Émises', s.parStatut[InvoiceStatut.emise] ?? 0, AppColors.orange),
                      _statLine('Acompte', s.parStatut[InvoiceStatut.payeePartiel] ?? 0, AppColors.gold),
                      _statLine('Soldées', s.parStatut[InvoiceStatut.payee] ?? 0, AppColors.g600),
                      _statLine('Brouillons', s.parStatut[InvoiceStatut.brouillon] ?? 0, AppColors.s400),
                      const Divider(),
                      _statLine('Total définitives', s.nbDefinitives, AppColors.g700, bold: true),
                      _statLine('Proformas (devis)', s.nbProformas, AppColors.blue),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/unpaid'),
                  icon: const Icon(Icons.hourglass_bottom_outlined, size: 18),
                  label: const Text('Voir les impayés / relances'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.orange),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
      ),
    );
  }

  Widget _statLine(String label, int n, Color color, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : null))),
            Text('$n', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      );
}

class _Kpi extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.s100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(label, style: const TextStyle(fontSize: 10, color: AppColors.s400)),
            ],
          ),
        ),
      );
}
