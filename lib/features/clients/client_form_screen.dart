import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../services/client_service.dart';

class ClientFormScreen extends StatefulWidget {
  final String? clientId;
  const ClientFormScreen({super.key, this.clientId});

  bool get isEditing => clientId != null;

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl    = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _telCtrl    = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _nineaCtrl  = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    final c = await ClientService().getById(widget.clientId!);
    if (c != null && mounted) {
      _nomCtrl.text     = c.nom;
      _contactCtrl.text = c.contact ?? '';
      _telCtrl.text     = c.telephone ?? '';
      _emailCtrl.text   = c.email ?? '';
      _adresseCtrl.text = c.adresse ?? '';
      _nineaCtrl.text   = c.ninea ?? '';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _contactCtrl.dispose(); _telCtrl.dispose();
    _emailCtrl.dispose(); _adresseCtrl.dispose(); _nineaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final fields = {
      'nom': _nomCtrl.text.trim(),
      if (_contactCtrl.text.isNotEmpty) 'contact': _contactCtrl.text.trim(),
      if (_telCtrl.text.isNotEmpty) 'telephone': _telCtrl.text.trim(),
      if (_emailCtrl.text.isNotEmpty) 'email': _emailCtrl.text.trim(),
      if (_adresseCtrl.text.isNotEmpty) 'adresse': _adresseCtrl.text.trim(),
      if (_nineaCtrl.text.isNotEmpty) 'ninea': _nineaCtrl.text.trim(),
    };

    try {
      final svc = ClientService();
      if (widget.isEditing) {
        await svc.update(widget.clientId!, fields);
      } else {
        await svc.create(fields);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.successCreate)));
        context.go('/clients');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Modifier client' : AppStrings.nouveauClient),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _field(_nomCtrl, AppStrings.nomSociete, required: true,
                        icon: Icons.business_outlined),
                    const SizedBox(height: 12),
                    _field(_contactCtrl, 'Nom contact', icon: Icons.person_outline),
                    const SizedBox(height: 12),
                    _field(_telCtrl, AppStrings.telephone,
                        keyboard: TextInputType.phone,
                        icon: Icons.phone_outlined),
                    const SizedBox(height: 12),
                    _field(_emailCtrl, 'Email',
                        keyboard: TextInputType.emailAddress,
                        icon: Icons.email_outlined),
                    const SizedBox(height: 12),
                    _field(_adresseCtrl, AppStrings.adresse, icon: Icons.location_on_outlined),
                    const SizedBox(height: 12),
                    _field(_nineaCtrl, AppStrings.ninea, icon: Icons.badge_outlined),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: Text(widget.isEditing ? 'Enregistrer' : 'Créer le client'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    TextInputType keyboard = TextInputType.text,
    IconData? icon,
  }) => TextFormField(
    controller: ctrl,
    keyboardType: keyboard,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
    ),
    validator: required
        ? (v) => v == null || v.isEmpty ? 'Champ obligatoire' : null
        : null,
  );
}
