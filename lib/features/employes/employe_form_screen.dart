import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/employe.dart';
import '../../services/employe_service.dart';

class EmployeFormScreen extends StatefulWidget {
  final String? employeId;
  const EmployeFormScreen({super.key, this.employeId});

  @override
  State<EmployeFormScreen> createState() => _EmployeFormScreenState();
}

class _EmployeFormScreenState extends State<EmployeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _init = true;
  bool _loadingMatricule = false;

  final _matriculeCtrl     = TextEditingController();
  final _nomCtrl           = TextEditingController();
  final _prenomCtrl        = TextEditingController();
  final _posteCtrl         = TextEditingController();
  final _telCtrl           = TextEditingController();
  final _salaireCtrl       = TextEditingController();
  final _partSalarialeCtrl = TextEditingController();
  final _partPatronaleCtrl = TextEditingController();
  final _fraisGestionCtrl  = TextEditingController();
  final _notesCtrl         = TextEditingController();

  DateTime? _dateEmbauche;
  EmployeStatut _statut = EmployeStatut.actif;
  String _fraisGestionType = 'montant'; // 'montant' | 'pct'
  Employe? _existing;

  EmployeCategorie? _categorie;
  String? _metierSel;          // métier choisi dans la liste, ou '__autre__'
  bool _metierAutre = false;   // true => saisie libre dans _posteCtrl
  static const _autre = 'Autre…';

  bool get _isEdit => widget.employeId != null;

  double get _brut         => double.tryParse(_salaireCtrl.text.replaceAll(' ', '')) ?? 0;
  double get _salariale    => double.tryParse(_partSalarialeCtrl.text.replaceAll(' ', '')) ?? 0;
  double get _patronale    => double.tryParse(_partPatronaleCtrl.text.replaceAll(' ', '')) ?? 0;
  double get _fraisValeur  => double.tryParse(_fraisGestionCtrl.text.replaceAll(' ', '')) ?? 0;
  double get _frais        => _fraisGestionType == 'pct' ? _brut * _fraisValeur / 100 : _fraisValeur;
  double get _netAPayer    => _brut - _salariale;
  double get _coutTotal    => _brut + _patronale + _frais;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadExisting();
    } else {
      _generateMatricule();
    }
  }

  Future<void> _generateMatricule() async {
    setState(() => _loadingMatricule = true);
    try {
      final m = await EmployeService().generateMatricule();
      if (mounted) _matriculeCtrl.text = m;
    } finally {
      if (mounted) setState(() { _loadingMatricule = false; _init = false; });
    }
  }

  Future<void> _loadExisting() async {
    final e = await EmployeService().getById(widget.employeId!);
    if (e != null && mounted) {
      setState(() {
        _existing              = e;
        _matriculeCtrl.text    = e.matricule ?? '';
        _nomCtrl.text          = e.nom;
        _prenomCtrl.text       = e.prenom ?? '';
        _posteCtrl.text        = e.poste ?? '';
        _categorie             = e.categorie;
        if (e.poste != null && e.poste!.isNotEmpty) {
          if (EmployeMetiers.all.contains(e.poste)) {
            _metierSel = e.poste;
            _metierAutre = false;
          } else {
            _metierSel = _autre;
            _metierAutre = true;
          }
        }
        _telCtrl.text          = e.telephone ?? '';
        _salaireCtrl.text       = e.salaireMensuel.round().toString();
        _partSalarialeCtrl.text = e.partSalariale.round().toString();
        _partPatronaleCtrl.text = e.partPatronale.round().toString();
        _fraisGestionType      = e.fraisGestionType;
        _fraisGestionCtrl.text = _fraisGestionType == 'pct'
            ? e.fraisGestionPct.toString()
            : e.fraisGestionMontant.round().toString();
        _notesCtrl.text        = e.notes ?? '';
        _dateEmbauche          = e.dateEmbauche;
        _statut                = e.statut;
        _init = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateEmbauche ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateEmbauche = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final employe = Employe(
        id:                   _existing?.id ?? '',
        matricule:            _matriculeCtrl.text.trim().isEmpty ? null : _matriculeCtrl.text.trim(),
        nom:                  _nomCtrl.text.trim(),
        prenom:               _prenomCtrl.text.trim().isEmpty ? null : _prenomCtrl.text.trim(),
        poste:                _posteCtrl.text.trim().isEmpty ? null : _posteCtrl.text.trim(),
        telephone:            _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
        salaireMensuel:       _brut,
        partSalariale:        _salariale,
        partPatronale:        _patronale,
        fraisGestionType:     _fraisGestionType,
        fraisGestionMontant:  _fraisGestionType == 'montant' ? _fraisValeur : 0,
        fraisGestionPct:      _fraisGestionType == 'pct' ? _fraisValeur : 0,
        dateEmbauche:         _dateEmbauche,
        statut:               _statut,
        notes:                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt:            _existing?.createdAt ?? DateTime.now(),
      );

      if (_isEdit) {
        await EmployeService().update(widget.employeId!, employe);
      } else {
        await EmployeService().create(employe);
      }

      if (mounted) context.pop();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _matriculeCtrl.dispose(); _nomCtrl.dispose(); _prenomCtrl.dispose();
    _posteCtrl.dispose(); _telCtrl.dispose(); _salaireCtrl.dispose();
    _partSalarialeCtrl.dispose(); _partPatronaleCtrl.dispose();
    _fraisGestionCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.g50,
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier employé' : 'Nouvel employé'),
        backgroundColor: AppColors.g700,
        foregroundColor: Colors.white,
      ),
      body: _init
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── Matricule ─────────────────────────────────────────
                    _section('Matricule', Icons.badge_outlined),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _matriculeCtrl,
                          decoration: _deco('Numéro de matricule',
                              hint: 'Ex: D2S-2026-001',
                              prefixIcon: Icons.tag_outlined),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Regénérer',
                        child: IconButton(
                          icon: _loadingMatricule
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh, color: AppColors.g600),
                          onPressed: _loadingMatricule ? null : () async {
                            setState(() => _loadingMatricule = true);
                            final m = await EmployeService().generateMatricule();
                            if (mounted) setState(() {
                              _matriculeCtrl.text = m;
                              _loadingMatricule = false;
                            });
                          },
                        ),
                      ),
                    ]),

                    const SizedBox(height: 20),
                    // ── Identité ─────────────────────────────────────────
                    _section('Identité', Icons.person_outline),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _field(_prenomCtrl, 'Prénom')),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_nomCtrl, 'Nom *',
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null)),
                    ]),
                    const SizedBox(height: 12),

                    // Catégorie : supervision / terrain
                    DropdownButtonFormField<EmployeCategorie?>(
                      value: _categorie,
                      decoration: _deco('Catégorie', prefixIcon: Icons.groups_outlined),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Non précisée')),
                        ...EmployeCategorie.values.map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c == EmployeCategorie.supervision
                                  ? '🧭 Supervision'
                                  : '🛠️ Terrain'),
                            )),
                      ],
                      onChanged: (v) => setState(() {
                        _categorie = v;
                        // Réinitialise le métier si plus cohérent avec la catégorie
                        final base = EmployeMetiers.forCategorie(v);
                        if (_metierSel != null &&
                            _metierSel != _autre &&
                            !base.contains(_metierSel)) {
                          _metierSel = null;
                          _metierAutre = false;
                          _posteCtrl.clear();
                        }
                      }),
                    ),
                    const SizedBox(height: 12),

                    // Métier (liste suggérée selon la catégorie + Autre…)
                    Builder(builder: (_) {
                      final base = EmployeMetiers.forCategorie(_categorie);
                      final items = <String>{
                        ...base,
                        if (_metierSel != null && _metierSel != _autre) _metierSel!,
                        _autre,
                      }.toList();
                      return DropdownButtonFormField<String>(
                        value: _metierSel,
                        isExpanded: true,
                        decoration: _deco('Métier / Fonction', prefixIcon: Icons.work_outline),
                        items: items
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _metierSel = v;
                          if (v == _autre) {
                            _metierAutre = true;
                            _posteCtrl.clear();
                          } else {
                            _metierAutre = false;
                            _posteCtrl.text = v ?? '';
                          }
                        }),
                      );
                    }),
                    if (_metierAutre) ...[
                      const SizedBox(height: 12),
                      _field(_posteCtrl, 'Préciser le métier', hint: 'Ex: Plombier, Électricien...'),
                    ],
                    const SizedBox(height: 12),
                    _field(_telCtrl, 'Téléphone', keyboard: TextInputType.phone),

                    const SizedBox(height: 20),
                    // ── Contrat ──────────────────────────────────────────
                    _section('Contrat & Rémunération', Icons.work_outline),
                    const SizedBox(height: 12),

                    // Salaire brut
                    TextFormField(
                      controller: _salaireCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                      onChanged: (_) => setState(() {}),
                      decoration: _deco('Salaire brut (FCFA) *', prefixIcon: Icons.payments_outlined),
                    ),
                    const SizedBox(height: 12),

                    // Part salariale
                    TextFormField(
                      controller: _partSalarialeCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        final val = double.tryParse(v) ?? 0;
                        if (val > _brut) return 'Ne peut pas dépasser le salaire brut';
                        return null;
                      },
                      decoration: _deco('Part salariale / Retenues (FCFA)', prefixIcon: Icons.remove_circle_outline),
                    ),
                    const SizedBox(height: 8),

                    // Net à payer (calculé)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.g50,
                        border: Border.all(color: AppColors.g100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net à payer',
                              style: TextStyle(fontSize: 13, color: AppColors.s500)),
                          Text(
                            Formatters.fcfa(_netAPayer),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.g700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Part patronale
                    TextFormField(
                      controller: _partPatronaleCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      decoration: _deco('Part patronale (FCFA)', prefixIcon: Icons.account_balance_outlined),
                    ),
                    const SizedBox(height: 12),

                    // Frais de gestion
                    _section('Frais de gestion', Icons.percent_outlined),
                    const SizedBox(height: 8),
                    Row(children: [
                      ToggleButtons(
                        isSelected: [_fraisGestionType == 'montant', _fraisGestionType == 'pct'],
                        onPressed: (i) => setState(() {
                          _fraisGestionType = i == 0 ? 'montant' : 'pct';
                          _fraisGestionCtrl.clear();
                        }),
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: AppColors.g600,
                        constraints: const BoxConstraints(minWidth: 110, minHeight: 40),
                        children: const [
                          Text('Montant fixe', style: TextStyle(fontSize: 13)),
                          Text('Pourcentage', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fraisGestionCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      onChanged: (_) => setState(() {}),
                      decoration: _deco(
                        _fraisGestionType == 'pct'
                            ? 'Pourcentage (%)'
                            : 'Montant fixe (FCFA)',
                        prefixIcon: _fraisGestionType == 'pct'
                            ? Icons.percent
                            : Icons.payments_outlined,
                        hint: _fraisGestionType == 'pct' ? 'Ex: 10' : 'Ex: 15000',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Coût total (calculé)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.g50,
                        border: Border.all(color: AppColors.g100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Coût total / mois',
                              style: TextStyle(fontSize: 13, color: AppColors.s500)),
                          Text(
                            Formatters.fcfa(_coutTotal),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.g700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date embauche
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: _deco('Date d\'embauche', prefixIcon: Icons.calendar_today_outlined),
                        child: Text(
                          _dateEmbauche != null
                              ? DateFormat('dd/MM/yyyy').format(_dateEmbauche!)
                              : 'Sélectionner...',
                          style: TextStyle(
                            color: _dateEmbauche != null ? Colors.black87 : AppColors.s300,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Statut
                    DropdownButtonFormField<EmployeStatut>(
                      value: _statut,
                      decoration: _deco('Statut', prefixIcon: Icons.toggle_on_outlined),
                      items: EmployeStatut.values.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.label),
                      )).toList(),
                      onChanged: (v) { if (v != null) setState(() => _statut = v); },
                    ),

                    const SizedBox(height: 20),
                    // ── Notes ────────────────────────────────────────────
                    _section('Notes', Icons.notes_outlined),
                    const SizedBox(height: 12),
                    _field(_notesCtrl, 'Notes / Observations', maxLines: 3),

                    const SizedBox(height: 28),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.g700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _loading ? null : _save,
                        icon: _loading
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(_loading ? 'Sauvegarde...' : 'Sauvegarder'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _section(String label, IconData icon) => Row(children: [
    Icon(icon, size: 16, color: AppColors.g700),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.g700)),
  ]);

  Widget _field(TextEditingController ctrl, String label, {
    String? hint, TextInputType? keyboard, int maxLines = 1,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: ctrl,
    validator: validator,
    keyboardType: keyboard,
    maxLines: maxLines,
    decoration: _deco(label, hint: hint),
  );

  InputDecoration _deco(String label, {String? hint, IconData? prefixIcon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.s300),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}
