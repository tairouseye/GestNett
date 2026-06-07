import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
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

  final _nomCtrl     = TextEditingController();
  final _prenomCtrl  = TextEditingController();
  final _posteCtrl   = TextEditingController();
  final _telCtrl     = TextEditingController();
  final _salaireCtrl = TextEditingController();
  final _notesCtrl   = TextEditingController();

  DateTime? _dateEmbauche;
  EmployeStatut _statut = EmployeStatut.actif;
  Employe? _existing;

  bool get _isEdit => widget.employeId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadExisting();
    else setState(() => _init = false);
  }

  Future<void> _loadExisting() async {
    final e = await EmployeService().getById(widget.employeId!);
    if (e != null && mounted) {
      setState(() {
        _existing      = e;
        _nomCtrl.text   = e.nom;
        _prenomCtrl.text = e.prenom ?? '';
        _posteCtrl.text  = e.poste ?? '';
        _telCtrl.text    = e.telephone ?? '';
        _salaireCtrl.text = e.salaireMensuel.round().toString();
        _notesCtrl.text  = e.notes ?? '';
        _dateEmbauche    = e.dateEmbauche;
        _statut          = e.statut;
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
        id:             _existing?.id ?? '',
        nom:            _nomCtrl.text.trim(),
        prenom:         _prenomCtrl.text.trim().isEmpty ? null : _prenomCtrl.text.trim(),
        poste:          _posteCtrl.text.trim().isEmpty ? null : _posteCtrl.text.trim(),
        telephone:      _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
        salaireMensuel: double.tryParse(_salaireCtrl.text.replaceAll(' ', '')) ?? 0,
        dateEmbauche:   _dateEmbauche,
        statut:         _statut,
        notes:          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt:      _existing?.createdAt ?? DateTime.now(),
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
    _nomCtrl.dispose(); _prenomCtrl.dispose(); _posteCtrl.dispose();
    _telCtrl.dispose(); _salaireCtrl.dispose(); _notesCtrl.dispose();
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
                    _field(_posteCtrl, 'Poste / Fonction', hint: 'Ex: Agent de nettoyage, Chef équipe...'),
                    const SizedBox(height: 12),
                    _field(_telCtrl, 'Téléphone', keyboard: TextInputType.phone),

                    const SizedBox(height: 20),
                    // ── Contrat ──────────────────────────────────────────
                    _section('Contrat', Icons.work_outline),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _salaireCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                      decoration: _deco('Salaire mensuel (FCFA) *', prefixIcon: Icons.payments_outlined),
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
