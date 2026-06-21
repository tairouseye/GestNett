import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/employe.dart';
import '../../models/expense.dart';
import '../../models/invoice.dart';
import '../../models/market.dart';
import '../../services/employe_service.dart';
import '../../services/expense_service.dart';
import '../../services/invoice_service.dart';
import '../../services/market_service.dart';
import '../../services/payment_service.dart';

class MarketDetailScreen extends StatefulWidget {
  final String marketId;
  const MarketDetailScreen({super.key, required this.marketId});

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends State<MarketDetailScreen> {
  Market? _market;
  List<Invoice> _invoices = [];
  List<Expense> _expenses = [];
  List<Affectation> _affectations = [];
  double _totalEncaisse = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      MarketService().getById(widget.marketId),
      InvoiceService().getAll(),
      ExpenseService().getByMarket(widget.marketId),
      EmployeService().getByMarket(widget.marketId),
    ]);
    final market      = results[0] as Market?;
    final allInvoices = results[1] as List<Invoice>;
    final expenses    = results[2] as List<Expense>;
    final affectations = results[3] as List<Affectation>;
    final marketInvoices =
        allInvoices.where((inv) => inv.marketId == widget.marketId).toList();
    final totalEncaisse = await PaymentService()
        .totalForInvoices(marketInvoices.map((i) => i.id).toList());
    if (mounted) {
      setState(() {
        _market = market;
        _invoices = marketInvoices;
        _expenses = expenses;
        _affectations = affectations;
        _totalEncaisse = totalEncaisse;
        _loading = false;
      });
    }
  }

  Future<void> _changeStatut(MarketStatut statut) async {
    setState(() => _loading = true);
    final updated =
        await MarketService().updateStatut(widget.marketId, statut);
    if (mounted) setState(() { _market = updated; _loading = false; });
  }

  // Les proformas (devis) sont exclues du facturé réel et du reste à encaisser.
  double get _totalFacture  =>
      _invoices.where((inv) => !inv.isProforma).fold(0.0, (s, inv) => s + inv.totalTtc);
  double get _totalDepenses => _expenses.fold(0.0, (s, e) => s + e.montant);
  double get _masseSalariale => _affectations
      .where((a) => a.enCours)
      .fold(0.0, (s, a) => s + a.coutTotal);
  double get _resteAEncaisser => _totalFacture - _totalEncaisse;
  double get _beneficeFacture  => _totalFacture  - _totalDepenses;
  double get _beneficeEncaisse => _totalEncaisse - _totalDepenses;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.g50,
      appBar: AppBar(
        title: Text(_market?.numero ?? 'Marché'),
        actions: [
          if (_market != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
              onPressed: () async {
                await context.push('/markets/${widget.marketId}/edit');
                _load();
              },
            ),
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
              onPressed: () async {
                await context.push('/invoices/new');
                _load();
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text('Facturer'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _market == null
              ? const Center(child: Text('Marché introuvable'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _MarketInfoCard(market: _market!),
                      const SizedBox(height: 12),
                      _BilanCard(
                        montantTotal: _market!.montantTotal,
                        totalFacture: _totalFacture,
                        totalEncaisse: _totalEncaisse,
                        resteAEncaisser: _resteAEncaisser,
                        totalDepenses: _totalDepenses,
                        beneficeFacture: _beneficeFacture,
                        beneficeEncaisse: _beneficeEncaisse,
                      ),
                      const SizedBox(height: 12),
                      _PersonnelSection(
                        affectations: _affectations,
                        masseSalariale: _masseSalariale,
                        onManage: () => context.push('/employes'),
                      ),
                      const SizedBox(height: 12),
                      _InvoicesSection(
                        invoices: _invoices,
                        onTap: (id) async {
                          await context.push('/invoices/$id');
                          _load();
                        },
                      ),
                      const SizedBox(height: 12),
                      _ExpensesSection(expenses: _expenses),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }
}

// ── Info marché ───────────────────────────────────────────────────────────────

class _MarketInfoCard extends StatelessWidget {
  final Market market;
  const _MarketInfoCard({required this.market});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (market.statut) {
      MarketStatut.enCours   => AppColors.statusEnCours,
      MarketStatut.enAttente => AppColors.statusEnAttente,
      MarketStatut.termine   => AppColors.statusTermine,
      MarketStatut.suspendu  => AppColors.statusSuspendu,
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
                  child: GestureDetector(
                    onTap: () => context.push('/clients/${market.clientId}'),
                    child: Row(children: [
                      Flexible(
                        child: Text(market.clientNom ?? 'Client',
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.open_in_new, size: 14, color: AppColors.g600),
                    ]),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.3)),
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
            _InfoRow('Montant contrat',
                Formatters.fcfa(market.montantTotal)),
            if (market.description != null)
              _InfoRow('Prestation', market.description!),
            if (market.dateDebut != null)
              _InfoRow('Début', Formatters.date(market.dateDebut!)),
            if (market.dateFin != null)
              _InfoRow('Fin', Formatters.date(market.dateFin!)),
          ],
        ),
      ),
    );
  }
}

// ── Bilan financier ───────────────────────────────────────────────────────────

class _BilanCard extends StatelessWidget {
  final double montantTotal, totalFacture, totalEncaisse, resteAEncaisser,
      totalDepenses, beneficeFacture, beneficeEncaisse;
  const _BilanCard({
    required this.montantTotal,
    required this.totalFacture,
    required this.totalEncaisse,
    required this.resteAEncaisser,
    required this.totalDepenses,
    required this.beneficeFacture,
    required this.beneficeEncaisse,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bilan financier',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 14),
            Row(
              children: [
                _KpiBox('Contrat', Formatters.fcfa(montantTotal),
                    AppColors.g700, Icons.handshake_outlined),
                const SizedBox(width: 8),
                _KpiBox('Facturé', Formatters.fcfa(totalFacture),
                    AppColors.blue, Icons.receipt_long_outlined),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _KpiBox('Encaissé', Formatters.fcfa(totalEncaisse),
                    AppColors.g600, Icons.account_balance_wallet_outlined),
                const SizedBox(width: 8),
                _KpiBox(
                  'Reste à encaisser',
                  Formatters.fcfa(resteAEncaisser),
                  resteAEncaisser > 0 ? AppColors.orange : AppColors.g600,
                  Icons.hourglass_bottom_outlined,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _KpiBox('Dépenses', Formatters.fcfa(totalDepenses),
                    AppColors.red, Icons.trending_down_outlined),
                const SizedBox(width: 8),
                const _KpiBoxSpacer(),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _KpiBox(
                  'Bénéf. facturé',
                  Formatters.fcfa(beneficeFacture),
                  beneficeFacture >= 0 ? AppColors.blue : AppColors.red,
                  beneficeFacture >= 0 ? Icons.trending_up : Icons.trending_down,
                ),
                const SizedBox(width: 8),
                _KpiBox(
                  'Bénéf. encaissé',
                  Formatters.fcfa(beneficeEncaisse),
                  beneficeEncaisse >= 0 ? AppColors.g600 : AppColors.red,
                  beneficeEncaisse >= 0 ? Icons.trending_up : Icons.trending_down,
                ),
              ],
            ),

            // Avancement de facturation (facturé vs contrat)
            if (montantTotal > 0) ...[
              const SizedBox(height: 14),
              Builder(builder: (_) {
                final pct = (totalFacture / montantTotal);
                final reste = montantTotal - totalFacture;
                final over = totalFacture > montantTotal;
                final barColor = over ? AppColors.red : AppColors.blue;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Avancement facturation',
                            style: TextStyle(fontSize: 12, color: AppColors.s500)),
                        Text('${(pct * 100).toStringAsFixed(0)} %',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold, color: barColor)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0, 1).toDouble(),
                        minHeight: 8,
                        backgroundColor: AppColors.s100,
                        color: barColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      over
                          ? 'Sur-facturation de ${Formatters.fcfa(totalFacture - montantTotal)}'
                          : 'Reste à facturer : ${Formatters.fcfa(reste)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: over ? AppColors.red : AppColors.s400),
                    ),
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _KpiBoxSpacer extends StatelessWidget {
  const _KpiBoxSpacer();
  @override
  Widget build(BuildContext context) => const Expanded(child: SizedBox());
}

class _KpiBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _KpiBox(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}

// ── Factures liées ────────────────────────────────────────────────────────────

class _InvoicesSection extends StatelessWidget {
  final List<Invoice> invoices;
  final void Function(String id) onTap;
  const _InvoicesSection(
      {required this.invoices, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Factures (${invoices.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        if (invoices.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const [
                  Icon(Icons.receipt_long_outlined,
                      color: AppColors.s300),
                  SizedBox(width: 12),
                  Text('Aucune facture sur ce marché',
                      style: TextStyle(color: AppColors.s400)),
                ],
              ),
            ),
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
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                onTap: () => onTap(inv.id),
                leading: CircleAvatar(
                  backgroundColor: sc.withValues(alpha: 0.1),
                  child: Icon(Icons.receipt_long,
                      color: sc, size: 18),
                ),
                title: Text(inv.numero,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                subtitle: Text(
                  DateFormat('dd MMM yyyy', 'fr_FR')
                      .format(inv.date),
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Formatters.fcfa(inv.totalTtc),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: sc,
                            fontSize: 12)),
                    Text(inv.statut.label,
                        style: TextStyle(
                            fontSize: 9,
                            color: sc,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ── Dépenses ──────────────────────────────────────────────────────────────────

class _ExpensesSection extends StatelessWidget {
  final List<Expense> expenses;
  const _ExpensesSection({required this.expenses});

  @override
  Widget build(BuildContext context) {
    // Groupe par rubrique
    final byType = <ExpenseType, double>{};
    for (final e in expenses) {
      byType[e.type] = (byType[e.type] ?? 0) + e.montant;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Dépenses (${expenses.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        if (expenses.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const [
                  Icon(Icons.trending_down_outlined,
                      color: AppColors.s300),
                  SizedBox(width: 12),
                  Text('Aucune dépense sur ce marché',
                      style: TextStyle(color: AppColors.s400)),
                ],
              ),
            ),
          )
        else ...[
          // Résumé par rubrique
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: byType.entries.map((entry) {
                  final t = entry.key;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(t.icon, size: 16, color: t.color),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(t.label,
                                style: const TextStyle(fontSize: 12))),
                        Text(Formatters.fcfa(entry.value),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: t.color)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Personnel ─────────────────────────────────────────────────────────────────

class _PersonnelSection extends StatelessWidget {
  final List<Affectation> affectations;
  final double masseSalariale;
  final VoidCallback onManage;
  const _PersonnelSection({required this.affectations, required this.masseSalariale, required this.onManage});

  @override
  Widget build(BuildContext context) {
    final enCours = affectations.where((a) => a.enCours).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(children: [
            Expanded(
              child: Text('Personnel (${enCours.length} actif${enCours.length > 1 ? 's' : ''})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            if (masseSalariale > 0)
              Text(Formatters.fcfa(masseSalariale) + '/mois',
                  style: const TextStyle(fontSize: 11, color: AppColors.red, fontWeight: FontWeight.w600)),
          ]),
        ),
        if (enCours.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.people_outline, color: AppColors.s300),
                const SizedBox(width: 12),
                const Expanded(child: Text('Aucun employé affecté',
                    style: TextStyle(color: AppColors.s400))),
                TextButton(onPressed: onManage, child: const Text('Gérer', style: TextStyle(fontSize: 12))),
              ]),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                ...enCours.map((a) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.g100,
                    child: Text(
                      a.employeNom?.isNotEmpty == true ? a.employeNom![0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.g700),
                    ),
                  ),
                  title: Text(a.employeNom ?? 'Employé',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Formatters.fcfa(a.coutTotal),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.s500)),
                      if (a.salaireMensuel != null)
                        Text('brut: ${Formatters.fcfa(a.salaireMensuel!)}',
                            style: const TextStyle(fontSize: 10, color: AppColors.s400)),
                    ],
                  ),
                )),
                ListTile(
                  dense: true,
                  onTap: onManage,
                  title: const Text('Gérer le personnel →',
                      style: TextStyle(fontSize: 12, color: AppColors.g600)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

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
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    ),
  );
}
