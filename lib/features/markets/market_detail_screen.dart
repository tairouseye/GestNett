import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/market.dart';
import '../../services/market_service.dart';

class MarketDetailScreen extends StatefulWidget {
  final String marketId;
  const MarketDetailScreen({super.key, required this.marketId});

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends State<MarketDetailScreen> {
  Market? _market;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await MarketService().getById(widget.marketId);
    if (mounted) setState(() { _market = m; _loading = false; });
  }

  Future<void> _changeStatut(MarketStatut statut) async {
    setState(() => _loading = true);
    final updated = await MarketService().updateStatut(widget.marketId, statut);
    if (mounted) setState(() { _market = updated; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_market?.numero ?? 'Marché'),
        actions: [
          if (_market != null)
            PopupMenuButton<MarketStatut>(
              icon: const Icon(Icons.more_vert),
              onSelected: _changeStatut,
              itemBuilder: (_) => MarketStatut.values
                  .map((s) => PopupMenuItem(value: s, child: Text(s.label)))
                  .toList(),
            ),
        ],
      ),
      floatingActionButton: _market != null
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.go('/invoices/new?marketId=${widget.marketId}'),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Facturer'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _market == null
              ? const Center(child: Text('Marché introuvable'))
              : _MarketBody(market: _market!),
    );
  }
}

class _MarketBody extends StatelessWidget {
  final Market market;
  const _MarketBody({required this.market});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (market.statut) {
      MarketStatut.enCours   => AppColors.statusEnCours,
      MarketStatut.enAttente => AppColors.statusEnAttente,
      MarketStatut.termine   => AppColors.statusTermine,
      MarketStatut.suspendu  => AppColors.statusSuspendu,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Carte principale
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        market.clientNom ?? 'Client',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(market.statut.label,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor)),
                    ),
                  ],
                ),
                const Divider(height: 20),
                _InfoRow('Numéro', market.numero),
                _InfoRow('Montant total', Formatters.fcfa(market.montantTotal)),
                if (market.description != null)
                  _InfoRow('Prestation', market.description!),
                if (market.dateDebut != null)
                  _InfoRow('Début', Formatters.date(market.dateDebut!)),
                if (market.dateFin != null)
                  _InfoRow('Fin', Formatters.date(market.dateFin!)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Actions rapides
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.go('/expenses'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Dépense'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(color: AppColors.s400, fontSize: 12)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    ),
  );
}
