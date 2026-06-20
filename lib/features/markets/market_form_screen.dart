import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/client.dart';
import '../../models/market.dart';
import '../../services/client_service.dart';
import '../../services/market_service.dart';

class MarketFormScreen extends StatefulWidget {
  final String? marketId;
  final String? initialClientId;
  const MarketFormScreen({super.key, this.marketId, this.initialClientId});

  @override
  State<MarketFormScreen> createState() => _MarketFormScreenState();
}

class _MarketFormScreenState extends State<MarketFormScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _descCtrl  = TextEditingController();
  final _montantCtrl = TextEditingController();

  List<Client> _clients = [];
  String? _selectedClientId;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  MarketStatut _statut = MarketStatut.enAttente;
  bool _loading = false;
  bool _loadingClients = true;

  bool get _isEdit => widget.marketId != null;

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.initialClientId;
    _loadClients();
    if (_isEdit) _loadExisting();
  }

  Future<void> _loadClients() async {
    try {
      final clients = await ClientService().getAll();
      if (mounted) setState(() { _clients = clients; _loadingClients = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingClients = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement clients : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadExisting() async {
    final m = await MarketService().getById(widget.marketId!);
    if (m != null && mounted) {
      setState(() {
        _selectedClientId  = m.clientId;
        _descCtrl.text     = m.description ?? '';
        _montantCtrl.text  = m.montantTotal.round().toString();
        _statut            = m.statut;
        _dateDebut         = m.dateDebut;
        _dateFin           = m.dateFin;
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => isStart ? _dateDebut = d : _dateFin = d);
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
      if (_isEdit) {
        await MarketService().update(widget.marketId!, {
          'description':  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          'montant_total': double.parse(_montantCtrl.text.replaceAll(' ', '').replaceAll(',', '')).round(),
          'statut':       _statut.value,
          if (_dateDebut != null) 'date_debut': _dateDebut!.toIso8601String().substring(0, 10),
          if (_dateFin != null)   'date_fin':   _dateFin!.toIso8601String().substring(0, 10),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Marché modifié avec succès')));
          context.pop();
        }
      } else {
        final market = Market(
          id: '',
          numero: '',
          clientId: _selectedClientId!,
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          montantTotal: double.parse(_montantCtrl.text.replaceAll(' ', '').replaceAll(',', '')),
          statut: _statut,
          dateDebut: _dateDebut,
          dateFin: _dateFin,
          createdAt: DateTime.now(),
        );
        await MarketService().create(market);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Marché créé avec succès')));
          context.go('/markets');
        }
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
    _descCtrl.dispose();
    _montantCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Modifier marché' : 'Nouveau marché')),
      body: _loadingClients
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sélection client (désactivée en édition)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedClientId,
                            decoration: const InputDecoration(
                              labelText: 'Client *',
                              prefixIcon: Icon(Icons.business_outlined),
                              hintText: 'Sélectionner un client',
                            ),
                            isExpanded: true,
                            items: _clients.isEmpty
                                ? [const DropdownMenuItem(
                                    value: '__none__',
                                    child: Text('Aucun client — créez-en un',
                                        style: TextStyle(color: Colors.grey)))]
                                : _clients.map((c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.nom,
                                        overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: _isEdit ? null : (v) => setState(() =>
                                _selectedClientId = v == '__none__' ? null : v),
                            validator: (v) => (v == null || v == '__none__')
                                ? 'Sélectionne un client' : null,
                          ),
                        ),
                        if (!_isEdit) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Nouveau client',
                            child: IconButton(
                              icon: const Icon(Icons.person_add_outlined, color: AppColors.g600),
                              onPressed: () async {
                                await context.push('/clients/new');
                                await _loadClients();
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description prestation',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _montantCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Montant total (FCFA) *',
                        prefixIcon: Icon(Icons.attach_money),
                        suffixText: 'FCFA',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Obligatoire';
                        final n = double.tryParse(v.replaceAll(' ', '').replaceAll(',', ''));
                        if (n == null || n <= 0) return 'Montant invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<MarketStatut>(
                      value: _statut,
                      decoration: const InputDecoration(
                        labelText: 'Statut',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: MarketStatut.values
                          .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                          .toList(),
                      onChanged: (v) => setState(() => _statut = v ?? _statut),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: _DateBtn(
                          label: 'Date début',
                          date: _dateDebut,
                          onTap: () => _pickDate(true),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _DateBtn(
                          label: 'Date fin',
                          date: _dateFin,
                          onTap: () => _pickDate(false),
                        )),
                      ],
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.white)
                            : Text(_isEdit ? 'Enregistrer les modifications' : 'Créer le marché'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DateBtn extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateBtn({required this.label, this.date, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.calendar_today_outlined, size: 16),
    label: Text(
      date != null ? '${date!.day}/${date!.month}/${date!.year}' : label,
      style: const TextStyle(fontSize: 12),
    ),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    ),
  );
}
