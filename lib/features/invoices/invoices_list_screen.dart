import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/logout_button.dart';
import '../../core/widgets/search_field.dart';
import '../../models/invoice.dart';
import '../../services/invoice_service.dart';

class InvoicesListScreen extends StatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen>
    with SingleTickerProviderStateMixin {
  List<Invoice> _invoices = [];
  bool _loading = true;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _invoices = await InvoiceService().getAll();
    if (mounted) setState(() => _loading = false);
  }

  String _query = '';

  bool _match(Invoice i) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return (i.clientNom ?? '').toLowerCase().contains(q) ||
        i.numero.toLowerCase().contains(q);
  }

  List<Invoice> get _all        => _invoices.where(_match).toList();
  List<Invoice> get _proformas  => _all.where((i) => i.isProforma).toList();
  List<Invoice> get _definitives => _all.where((i) => !i.isProforma).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Factures'),
        actions: const [LogoutButton()],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.g700,
          unselectedLabelColor: AppColors.s400,
          indicatorColor: AppColors.g600,
          tabs: [
            Tab(text: 'Toutes (${_all.length})'),
            Tab(text: 'Proforma (${_proformas.length})'),
            Tab(text: 'Définitives (${_definitives.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/invoices/new'),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SearchField(
                  hint: 'Rechercher (client, n° facture)',
                  onChanged: (v) => setState(() => _query = v),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _InvoiceList(invoices: _all,         onRefresh: _load),
                      _InvoiceList(invoices: _proformas,   onRefresh: _load),
                      _InvoiceList(invoices: _definitives, onRefresh: _load),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  final List<Invoice> invoices;
  final Future<void> Function() onRefresh;
  const _InvoiceList({required this.invoices, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) return const _EmptyState();
    return RefreshIndicator(
      color: AppColors.g500,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _InvoiceTile(
          invoice: invoices[i],
          onTap: () async {
            await context.push('/invoices/${invoices[i].id}');
            onRefresh();
          },
        ),
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  const _InvoiceTile({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (invoice.statut) {
      InvoiceStatut.payee        => AppColors.g600,
      InvoiceStatut.payeePartiel => AppColors.gold,
      InvoiceStatut.emise        => AppColors.orange,
      InvoiceStatut.annulee      => AppColors.red,
      InvoiceStatut.brouillon    => AppColors.s400,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: invoice.isProforma
                ? const Color(0xFF1B4F8A).withValues(alpha: 0.3)
                : AppColors.s100,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.receipt_long, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        invoice.clientNom ?? 'Client',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    if (invoice.isProforma)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B4F8A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('PROFORMA',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B4F8A))),
                      ),
                  ]),
                  Text(
                    invoice.numero,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.s400, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.fcfa(invoice.totalTtc),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.g700),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    invoice.statut.label,
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.s200),
        SizedBox(height: 12),
        Text('Aucune facture', style: TextStyle(color: AppColors.s400)),
        SizedBox(height: 4),
        Text('Appuie sur + pour créer une facture',
            style: TextStyle(color: AppColors.s300, fontSize: 12)),
      ],
    ),
  );
}
