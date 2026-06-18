import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/logout_button.dart';
import '../../core/widgets/search_field.dart';
import '../../models/market.dart';
import '../../services/market_service.dart';

class MarketsListScreen extends StatefulWidget {
  const MarketsListScreen({super.key});

  @override
  State<MarketsListScreen> createState() => _MarketsListScreenState();
}

class _MarketsListScreenState extends State<MarketsListScreen> {
  List<Market> _markets = [];
  bool _loading = true;
  String _query = '';

  bool _match(Market m) {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Marchés'), actions: const [LogoutButton()]),
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
                  return Column(
                    children: [
                      SearchField(
                        hint: 'Rechercher (client, n° marché, prestation)',
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      Expanded(
                        child: list.isEmpty
                            ? const Center(child: Text('Aucun résultat', style: TextStyle(color: AppColors.s400)))
                            : RefreshIndicator(
                                color: AppColors.g500,
                                onRefresh: _load,
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: list.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (_, i) => _MarketTile(market: list[i]),
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
  const _MarketTile({required this.market});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (market.statut) {
      MarketStatut.enCours   => AppColors.statusEnCours,
      MarketStatut.enAttente => AppColors.statusEnAttente,
      MarketStatut.termine   => AppColors.statusTermine,
      MarketStatut.suspendu  => AppColors.statusSuspendu,
    };

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
          ],
        ),
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
