import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/market.dart';
import '../../models/recurrence.dart';
import '../../services/market_service.dart';
import '../../services/recurrence_service.dart';

class RecurrenceFormScreen extends StatefulWidget {
  final String? recurrenceId;
  const RecurrenceFormScreen({super.key, this.recurrenceId});

  @override
  State<RecurrenceFormScreen> createState() => _RecurrenceFormScreenState();
}

class _RecurrenceFormScreenState extends State<RecurrenceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _tvaCtrl = TextEditingController(text: '18');
  final _libelleCtrl = TextEditingController();

  List<Market> _markets = [];
  String? _selectedMarketId;
  String? _clientId;
  Frequence _frequence = Frequence.mensuelle;
  int _jourDuMois = 1;
  String _typeFacture = 'definitive';
  bool _actif = true;
  DateTime _prochaineDate = DateTime.now();

  bool _loadingMarkets = true;
  bool _loading = false;

  bool get _isEdit => widget.recurrenceId != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final markets = await MarketService().getAll();
      if (!mounted) return;
      setState(() {
        _markets = markets;
        _loadingMarkets = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMarkets = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur chargement marchés : $e')));
      }
    }
    if (_isEdit) await _loadExisting();
  }

  Future<void> _loadExisting() async {
    final r = await RecurrenceService().getById(widget.recurrenceId!);
    if (r != null && mounted) {
      setState(() {
        _selectedMarketId = r.marketId;
        _clientId = r.clientId;
        _montantCtrl.text = r.montantHt.round().toString();
        _tvaCtrl.text = r.tvaPct.round().toString();
        _libelleCtrl.text = r.libelle ?? '';
        _frequence = r.frequence;
        _jourDuMois = r.jourDuMois;
        _typeFacture = r.typeFacture;
        _actif = r.actif;
        _prochaineDate = r.prochaineDate;
      });
    }
  }

  void _onMarketSelected(String? id) {
    if (id == null) return;
    final m = _markets.firstWhere((e) => e.id == id);
    setState(() {
      _selectedMarketId = id;
      _clientId = m.clientId;
      // Pré-remplit le montant depuis le marché s'il est vide.
      if (_montantCtrl.text.trim().isEmpty && m.montantTotal > 0) {
        _montantCtrl.text = m.montantTotal.round().toString();
      }
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _prochaineDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => _prochaineDate = d);
  }

  double get _montantHt =>
      double.tryParse(_montantCtrl.text.replaceAll(' ', '').replaceAll(',', '')) ?? 0;
  double get _tvaPct => double.tryParse(_tvaCtrl.text.replaceAll(',', '.')) ?? 18;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMarketId == null || _clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sélectionne un marché')));
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isEdit) {
        await RecurrenceService().update(widget.recurrenceId!, {
          'market_id': _selectedMarketId,
          'client_id': _clientId,
          'montant_ht': _montantHt.round(),
          'tva_pct': _tvaPct,
          'frequence': _frequence.value,
          'jour_du_mois': _jourDuMois,
          'type_facture': _typeFacture,
          'libelle': _libelleCtrl.text.trim().isEmpty
              ? null
              : _libelleCtrl.text.trim(),
          'actif': _actif,
          'prochaine_date': _prochaineDate.toIso8601String().substring(0, 10),
        });
      } else {
        await RecurrenceService().create(Recurrence(
          id: '',
          marketId: _selectedMarketId!,
          clientId: _clientId!,
          montantHt: _montantHt,
          tvaPct: _tvaPct,
          frequence: _frequence,
          jourDuMois: _jourDuMois,
          typeFacture: _typeFacture,
          libelle: _libelleCtrl.text.trim().isEmpty
              ? null
              : _libelleCtrl.text.trim(),
          actif: _actif,
          prochaineDate: _prochaineDate,
          createdAt: DateTime.now(),
        ));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEdit ? 'Récurrence modifiée' : 'Récurrence créée')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _tvaCtrl.dispose();
    _libelleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ttc = _montantHt * (1 + _tvaPct / 100);
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? 'Modifier récurrence' : 'Nouvelle récurrence')),
      body: _loadingMarkets
          ? const Center(child: CircularProgressIndicator())
          : _markets.isEmpty
              ? const _NoMarkets()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedMarketId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Marché *',
                            prefixIcon: Icon(Icons.handshake_outlined),
                            hintText: 'Sélectionner un marché',
                          ),
                          items: _markets
                              .map((m) => DropdownMenuItem(
                                    value: m.id,
                                    child: Text(
                                      '${m.clientNom ?? m.numero} — ${m.numero}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: _onMarketSelected,
                          validator: (v) =>
                              v == null ? 'Sélectionne un marché' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _montantCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Montant HT (FCFA) *',
                            prefixIcon: Icon(Icons.attach_money),
                            suffixText: 'FCFA',
                          ),
                          validator: (v) {
                            final n = double.tryParse(
                                (v ?? '').replaceAll(' ', '').replaceAll(',', ''));
                            if (n == null || n <= 0) return 'Montant invalide';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _tvaCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'TVA (%)',
                            prefixIcon: Icon(Icons.percent),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('Total TTC : ${Formatters.fcfa(ttc)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.g700)),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Frequence>(
                          value: _frequence,
                          decoration: const InputDecoration(
                            labelText: 'Fréquence',
                            prefixIcon: Icon(Icons.repeat),
                          ),
                          items: Frequence.values
                              .map((f) => DropdownMenuItem(
                                  value: f, child: Text(f.label)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _frequence = v ?? _frequence),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _jourDuMois,
                          decoration: const InputDecoration(
                            labelText: 'Jour du mois',
                            prefixIcon: Icon(Icons.today_outlined),
                          ),
                          items: [
                            for (var j = 1; j <= 28; j++)
                              DropdownMenuItem(value: j, child: Text('Le $j'))
                          ],
                          onChanged: (v) =>
                              setState(() => _jourDuMois = v ?? _jourDuMois),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _typeFacture,
                          decoration: const InputDecoration(
                            labelText: 'Type de facture',
                            prefixIcon: Icon(Icons.receipt_long_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'definitive', child: Text('Définitive')),
                            DropdownMenuItem(
                                value: 'proforma', child: Text('Proforma')),
                          ],
                          onChanged: (v) =>
                              setState(() => _typeFacture = v ?? _typeFacture),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today_outlined,
                              size: 16),
                          label: Text(
                              'Prochaine génération : ${Formatters.dateShort(_prochaineDate)}'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _libelleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Libellé (optionnel)',
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          value: _actif,
                          activeColor: AppColors.g500,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active'),
                          subtitle: const Text(
                              'Génère automatiquement les factures dues'),
                          onChanged: (v) => setState(() => _actif = v),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const CircularProgressIndicator(
                                    strokeWidth: 2.5, color: AppColors.white)
                                : Text(_isEdit
                                    ? 'Enregistrer'
                                    : 'Créer la récurrence'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _NoMarkets extends StatelessWidget {
  const _NoMarkets();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.handshake_outlined,
                  size: 56, color: AppColors.s200),
              const SizedBox(height: 12),
              const Text('Aucun marché disponible',
                  style: TextStyle(color: AppColors.s400, fontSize: 16)),
              const SizedBox(height: 4),
              const Text(
                'Crée d\'abord un marché pour pouvoir planifier ses factures récurrentes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.s300, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/markets/new'),
                child: const Text('Nouveau marché'),
              ),
            ],
          ),
        ),
      );
}
