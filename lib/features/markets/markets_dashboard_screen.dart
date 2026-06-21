import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/market.dart';
import '../../services/market_service.dart';
import '../../providers/markets_stats_provider.dart';

final _marketsProvider = FutureProvider<List<Market>>((ref) => MarketService().getAll());

class MarketsDashboardScreen extends ConsumerWidget {
  const MarketsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketsAsync = ref.watch(_marketsProvider);
    final stats = ref.watch(marketsStatsProvider).valueOrNull ?? {};

    return Scaffold(
      backgroundColor: AppColors.g50,
      appBar: AppBar(
        title: const Text('Tableau de bord Marchés'),
        backgroundColor: AppColors.g700,
        foregroundColor: Colors.white,
      ),
      body: marketsAsync.when(
        data: (markets) {
          final actifs = markets.where((m) => m.statut == MarketStatut.enCours).toList();
          final contractuel = markets.fold<double>(0, (s, m) => s + m.montantTotal);
          final facture = stats.values.fold<double>(0, (s, v) => s + v.facture);
          final encaisse = stats.values.fold<double>(0, (s, v) => s + v.encaisse);
          final depenses = stats.values.fold<double>(0, (s, v) => s + v.depenses);
          final reste = facture - encaisse;
          final marge = encaisse - depenses;

          final now = DateTime.now();
          final enRetard = actifs
              .where((m) => m.dateFin != null &&
                  m.dateFin!.isBefore(DateTime(now.year, now.month, now.day)))
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_marketsProvider);
              ref.invalidate(marketsStatsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  _Kpi('Marchés actifs', '${actifs.length}', Icons.handshake_outlined, AppColors.g700),
                  const SizedBox(width: 8),
                  _Kpi('Total marchés', '${markets.length}', Icons.folder_outlined, AppColors.s500),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _Kpi('Contractuel', Formatters.fcfa(contractuel), Icons.description_outlined, AppColors.g700),
                  const SizedBox(width: 8),
                  _Kpi('Facturé', Formatters.fcfa(facture), Icons.receipt_long_outlined, AppColors.blue),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _Kpi('Encaissé', Formatters.fcfa(encaisse), Icons.account_balance_wallet_outlined, AppColors.g600),
                  const SizedBox(width: 8),
                  _Kpi('Reste à encaisser', Formatters.fcfa(reste),
                      Icons.hourglass_bottom_outlined, reste > 0 ? AppColors.orange : AppColors.g600),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _Kpi('Dépenses', Formatters.fcfa(depenses), Icons.trending_down_outlined, AppColors.red),
                  const SizedBox(width: 8),
                  _Kpi('Marge (encaissé)', Formatters.fcfa(marge),
                      marge >= 0 ? Icons.trending_up : Icons.trending_down,
                      marge >= 0 ? AppColors.g600 : AppColors.red),
                ]),
                const SizedBox(height: 16),

                _EcheancesCard(
                  markets: enRetard,
                  onTap: (id) => context.push('/markets/$id'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
      ),
    );
  }
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

class _EcheancesCard extends StatelessWidget {
  final List<Market> markets;
  final void Function(String id) onTap;
  const _EcheancesCard({required this.markets, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔴 Marchés en retard d\'échéance',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.red)),
            if (markets.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Aucun marché en retard', style: TextStyle(fontSize: 12, color: AppColors.s400)),
              )
            else
              ...markets.map((m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onTap: () => onTap(m.id),
                    leading: const Icon(Icons.event_busy, color: AppColors.red, size: 20),
                    title: Text(m.numero, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${m.clientNom ?? ''} · fin ${Formatters.dateShort(m.dateFin!)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 16, color: AppColors.s300),
                  )),
          ],
        ),
      ),
    );
  }
}
