import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/logout_button.dart';
import '../../core/widgets/search_field.dart';
import '../../models/market.dart';
import '../../services/market_service.dart';
import '../../providers/markets_stats_provider.dart';

enum _Sort { recent, montant }

class MarketsListScreen extends ConsumerStatefulWidget {
  const MarketsListScreen({super.key});

  @override
  ConsumerState<MarketsListScreen> createState() => _MarketsListScreenState();
}

class _MarketsListScreenState extends ConsumerState<MarketsListScreen> {
  List<Market> _markets = [];
  bool _loading = true;
  String _query = '';
  MarketStatut? _statutFiltre;
  _Sort _sort = _Sort.recent;

  bool _match(Market m) {
    if (_statutFiltre != null && m.statut != _statutFiltre) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return (m.clientNom ?? '').toLowerCase().contains(q) ||
        m.numero.toLowerCase().contains(q) ||
        (m.description ?? '').toLowerCase().contains(q);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _markets = await MarketService().getAll();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(marketsStatsProvider).valueOrNull ?? {};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marchés'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Tableau de bord',
            onPressed: () => context.push('/markets/dashboard'),
          ),
          PopupMenuButton<_Sort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Trier',
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Sort.recent, child: Text('Plus récents')),
              PopupMenuItem(value: _Sort.montant, child: Text('Montant ↓')),
            ],
          ),
          const LogoutButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/markets/new'),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _markets.isEmpty
              ? const _EmptyState()
              : Builder(builder: (_) {
                  final list = _markets.where(_match).toList();
                  switch (_sort) {
                    case _Sort.recent:
                      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    case _Sort.montant:
                      list.sort((a, b) => b.montantTotal.compareTo(a.montantTotal));
                  }
                  return Column(
                    children: [
                      SearchField(
                        hint: 'Rechercher (client, n° marché, prestation)',
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      _StatutFilters(
                        value: _statutFiltre,
                        onChanged: (s) => setState(() => _statutFiltre = s),
                      ),
                      Expanded(
                        child: list.isEmpty
                            ? const Center(child: Text('Aucun résultat', style: TextStyle(color: AppColors.s400)))
                            : RefreshIndicator(
                                color: AppColors.g500,
                                onRefresh: () async {
                                  await _load();
                                  ref.invalidate(marketsStatsProvider);
                                },
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: list.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (_, i) =>
                                      _MarketTile(market: list[i], stat: stats[list[i].id]),
                                ),
                              ),
                      ),
                    ],
                  );
                }),
    );
  }
}

class _MarketTile extends StatelessWidget {
  final Market market;
  final MarketStat? stat;
  const _MarketTile({required this.market, this.stat});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (market.statut) {
      MarketStatut.enCours   => AppColors.statusEnCours,
      MarketStatut.enAttente => AppColors.statusEnAttente,
      MarketStatut.termine   => AppColors.statusTermine,
      MarketStatut.suspendu  => AppColors.statusSuspendu,
    };

    // Échéance proche (en cours, date de fin ≤ 7 j)
    int? joursFin;
    if (market.statut == MarketStatut.enCours && market.dateFin != null) {
      final now = DateTime.now();
      joursFin = market.dateFin!.difference(DateTime(now.year, now.month, now.day)).inDays;
    }
    final echeanceProche = joursFin != null && joursFin <= 7;

    final pct = (stat != null && market.montantTotal > 0)
        ? (stat!.facture / market.montantTotal).clamp(0.0, 1.0).toDouble()
        : null;

    return InkWell(
      onTap: () => context.go('/markets/${market.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.s100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    market.clientNom ?? market.clientId,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                if (echeanceProche)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      joursFin! < 0 ? Icons.event_busy : Icons.event_outlined,
                      size: 16,
                      color: joursFin < 0 ? AppColors.red : AppColors.orange,
                    ),
                  ),
                _StatusChip(label: market.statut.label, color: statusColor),
              ],
            ),
            const SizedBox(height: 4),
            Text(market.numero,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.s400,
                    fontFamily: 'monospace')),
            if (market.description != null) ...[
              const SizedBox(height: 4),
              Text(
                market.description!,
                style: const TextStyle(fontSize: 12, color: AppColors.s500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 14, color: AppColors.s400),
                const SizedBox(width: 4),
                Text(
                  Formatters.fcfa(market.montantTotal),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.g700),
                ),
                const Spacer(),
                if (market.dateFin != null)
                  Text(
                    'Fin: ${Formatters.dateShort(market.dateFin!)}',
                    style: const TextStyle(fontSize: 10, color: AppColors.s400),
                  ),
              ],
            ),
            // Avancement de facturation
            if (pct != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 5,
                        backgroundColor: AppColors.s100,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${(pct * 100).toStringAsFixed(0)}% facturé',
                      style: const TextStyle(fontSize: 9, color: AppColors.s400)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatutFilters extends StatelessWidget {
  final MarketStatut? value;
  final ValueChanged<MarketStatut?> onChanged;
  const _StatutFilters({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, MarketStatut? s) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            selected: value == s,
            onSelected: (_) => onChanged(s),
            selectedColor: AppColors.g600,
            labelStyle: TextStyle(color: value == s ? Colors.white : AppColors.s500),
            backgroundColor: AppColors.white,
            side: BorderSide(color: value == s ? AppColors.g600 : AppColors.s100),
          ),
        );
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('Tous', null),
          chip('En cours', MarketStatut.enCours),
          chip('En attente', MarketStatut.enAttente),
          chip('Terminé', MarketStatut.termine),
          chip('Suspendu', MarketStatut.suspendu),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.handshake_outlined, size: 64, color: AppColors.s200),
        SizedBox(height: 12),
        Text('Aucun marché', style: TextStyle(color: AppColors.s400, fontSize: 16)),
        SizedBox(height: 4),
        Text('Appuie sur + pour créer un marché',
            style: TextStyle(color: AppColors.s300, fontSize: 12)),
      ],
    ),
  );
}
