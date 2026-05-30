import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/client.dart';
import '../../models/invoice.dart';
import '../../services/client_service.dart';
import '../../services/invoice_service.dart';

class InvoiceFormScreen extends StatefulWidget {
  final String? clientId;
  final String? marketId;
  const InvoiceFormScreen({super.key, this.clientId, this.marketId});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _htCtrl  = TextEditingController();
  double _tva = 18.0;
  DateTime _date = DateTime.now();

  List<Client> _clients = [];
  String? _selectedClientId;
  bool _loading = false;
  bool _loadingClients = true;

  double get _montantTva => _ht * _tva / 100;
  double get _totalTtc   => _ht + _montantTva;
  double get _ht => double.tryParse(
      _htCtrl.text.replaceAll(' ', '').replaceAll(',', '')) ?? 0;

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.clientId;
    _loadClients();
    _htCtrl.addListener(() => setState(() {}));
  }

  Future<void> _loadClients() async {
    _clients = await ClientService().getAll();
    if (mounted) setState(() => _loadingClients = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sélectionne un client')));
      return;
    }
    setState(() => _loading = true);
    try {
      final invoice = Invoice(
        id: '',
        numero: '',
        clientId: _selectedClientId!,
        marketId: widget.marketId,
        date: _date,
        montantHt: _ht,
        tvaPct: _tva,
        totalTtc: _totalTtc,
        statut: InvoiceStatut.brouillon,
        createdAt: DateTime.now(),
      );
      await InvoiceService().create(invoice);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Facture créée')));
        context.go('/invoices');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _htCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle facture')),
      body: _loadingClients
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Client
                    DropdownButtonFormField<String>(
                      value: _selectedClientId,
                      decoration: const InputDecoration(
                        labelText: 'Client *',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      items: _clients
                          .map((c) => DropdownMenuItem(
                              value: c.id, child: Text(c.nom)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedClientId = v),
                    ),
                    const SizedBox(height: 12),

                    // Montant HT
                    TextFormField(
                      controller: _htCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Montant HT (FCFA) *',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Obligatoire';
                        final n = double.tryParse(
                            v.replaceAll(' ', '').replaceAll(',', ''));
                        if (n == null || n <= 0) return 'Montant invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // TVA
                    DropdownButtonFormField<double>(
                      value: _tva,
                      decoration: const InputDecoration(
                        labelText: 'TVA',
                        prefixIcon: Icon(Icons.percent),
                      ),
                      items: [0.0, 18.0, 20.0]
                          .map((t) => DropdownMenuItem<double>(
                              value: t, child: Text('$t%')))
                          .toList(),
                      onChanged: (v) => setState(() => _tva = v ?? 18),
                    ),
                    const SizedBox(height: 16),

                    // Récapitulatif
                    if (_ht > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.g50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.g300),
                        ),
                        child: Column(
                          children: [
                            _RecapRow('Montant HT',
                                '${_ht.toStringAsFixed(0)} FCFA'),
                            _RecapRow('TVA ($_tva%)',
                                '${_montantTva.toStringAsFixed(0)} FCFA'),
                            const Divider(),
                            _RecapRow('Total TTC',
                                '${_totalTtc.toStringAsFixed(0)} FCFA',
                                bold: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const CircularProgressIndicator(
                                strokeWidth: 2.5, color: AppColors.white)
                            : const Text('Créer la facture'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _RecapRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontSize: 13, color: bold ? AppColors.g700 : AppColors.s500,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        Text(value, style: TextStyle(
          fontSize: 13, color: bold ? AppColors.g700 : AppColors.s700,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      ],
    ),
  );
}
