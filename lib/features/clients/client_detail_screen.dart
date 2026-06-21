import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/contact_actions.dart';
import '../../models/client.dart';
import '../../models/invoice.dart';
import '../../models/market.dart';
import '../../services/client_service.dart';
import '../../services/invoice_service.dart';
import '../../services/market_service.dart';
import '../../services/payment_service.dart';

class ClientDetailScreen extends StatefulWidget {
  final String clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  Client? _client;
  List<Market> _markets = [];
  List<Invoice> _invoices = [];
  double _encaisse = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = await ClientService().getById(widget.clientId);
    final markets = await MarketService().getByClient(widget.clientId);
    final invoices = await InvoiceService().getByClient(widget.clientId);
    // Factures dues = définitives non annulées
    final dues = invoices
        .where((i) => !i.isProforma && i.statut != InvoiceStatut.annulee)
        .toList();
    final encaisse =
        await PaymentService().totalForInvoices(dues.map((i) => i.id).toList());
    if (mounted) {
      setState(() {
        _client = client;
        _markets = markets;
        _invoices = invoices;
        _encaisse = encaisse;
        _loading = false;
      });
    }
  }

  double get _caFacture => _invoices
      .where((i) => !i.isProforma && i.statut != InvoiceStatut.annulee)
      .fold(0.0, (s, i) => s + i.totalTtc);
  double get _reste => _caFacture - _encaisse;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.g50,
      appBar: AppBar(
        title: Text(_client?.nom ?? 'Client'),
        actions: [
          if (_client != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await context.push('/clients/${widget.clientId}/edit');
                _load();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _client == null
              ? const Center(child: Text('Client introuvable'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _InfoCard(client: _client!),
                      const SizedBox(height: 12),
                      ContactActions(
                        telephone: _client!.telephone,
                        email: _client!.email,
                        waMessage: 'Bonjour ${_client!.contact ?? _client!.nom},\n\n'
                            'Nous espérons que vous allez bien. '
                            'N\'hésitez pas à nous contacter pour toute demande.\n\n'
                            'Cordialement.',
                      ),
                      const SizedBox(height: 12),
                      _CaCard(
                        facture: _caFacture,
                        encaisse: _encaisse,
                        reste: _reste,
                      ),
                      const SizedBox(height: 12),
                      _MarketsCard(
                        markets: _markets,
                        onTap: (id) async {
                          await context.push('/markets/$id');
                          _load();
                        },
                      ),
                      const SizedBox(height: 12),
                      _InvoicesCard(
                        invoices: _invoices,
                        onTap: (id) async {
                          await context.push('/invoices/$id');
                          _load();
                        },
                      ),
                      const SizedBox(height: 12),
                      _ActionRow(clientId: _client!.id),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Client client;
  const _InfoCard({required this.client});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informations', style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 20),
            _Row(label: 'Nom / Société', value: client.nom),
            if (client.type != null)
              _Row(label: 'Type', value: client.typeLabel),
            if (client.contact != null) _Row(label: 'Contact', value: client.contact!),
            if (client.telephone != null) _Row(label: 'Téléphone', value: client.telephone!),
            if (client.email != null) _Row(label: 'Email', value: client.email!),
            if (client.adresse != null) _Row(label: 'Adresse', value: client.adresse!),
            if (client.ninea != null) _Row(label: 'NINEA', value: client.ninea!),
            if (client.notes != null) _Row(label: 'Notes', value: client.notes!),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(color: AppColors.s400, fontSize: 12)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      );
}

class _CaCard extends StatelessWidget {
  final double facture, encaisse, reste;
  const _CaCard({required this.facture, required this.encaisse, required this.reste});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chiffre d\'affaires',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Row(children: [
              _box('Facturé', facture, AppColors.blue),
              const SizedBox(width: 8),
              _box('Encaissé', encaisse, AppColors.g600),
              const SizedBox(width: 8),
              _box('Reste à encaisser', reste, reste > 0 ? AppColors.orange : AppColors.g600),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _box(String label, double value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(Formatters.fcfa(value),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

class _MarketsCard extends StatelessWidget {
  final List<Market> markets;
  final void Function(String id) onTap;
  const _MarketsCard({required this.markets, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Marchés (${markets.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            if (markets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucun marché', style: TextStyle(fontSize: 12, color: AppColors.s400)),
              )
            else
              ...markets.map((m) {
                final sc = switch (m.statut) {
                  MarketStatut.enCours   => AppColors.statusEnCours,
                  MarketStatut.enAttente => AppColors.statusEnAttente,
                  MarketStatut.termine   => AppColors.statusTermine,
                  MarketStatut.suspendu  => AppColors.statusSuspendu,
                };
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  onTap: () => onTap(m.id),
                  leading: Icon(Icons.handshake_outlined, color: sc, size: 20),
                  title: Text(m.numero, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(m.statut.label, style: TextStyle(fontSize: 11, color: sc)),
                  trailing: Text(Formatters.fcfa(m.montantTotal),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _InvoicesCard extends StatelessWidget {
  final List<Invoice> invoices;
  final void Function(String id) onTap;
  const _InvoicesCard({required this.invoices, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Factures (${invoices.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            if (invoices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucune facture', style: TextStyle(fontSize: 12, color: AppColors.s400)),
              )
            else
              ...invoices.map((inv) {
                final sc = switch (inv.statut) {
                  InvoiceStatut.payee        => AppColors.g600,
                  InvoiceStatut.payeePartiel => AppColors.gold,
                  InvoiceStatut.emise        => AppColors.orange,
                  InvoiceStatut.annulee      => AppColors.red,
                  InvoiceStatut.brouillon    => AppColors.s400,
                };
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  onTap: () => onTap(inv.id),
                  leading: Icon(Icons.receipt_long, color: sc, size: 20),
                  title: Text(inv.numero,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${inv.statut.label} · ${DateFormat('dd/MM/yyyy').format(inv.date)}',
                    style: TextStyle(fontSize: 11, color: sc),
                  ),
                  trailing: Text(Formatters.fcfa(inv.totalTtc),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String clientId;
  const _ActionRow({required this.clientId});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.go('/invoices/new?clientId=$clientId'),
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('Nouvelle facture'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.go('/markets/new?clientId=$clientId'),
              icon: const Icon(Icons.handshake_outlined, size: 18),
              label: const Text('Nouveau marché'),
            ),
          ),
        ],
      );
}
