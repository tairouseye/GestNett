import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/company_settings.dart';
import '../../services/company_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  CompanySettings? _settings;

  final _nameCtrl      = TextEditingController();
  final _sloganCtrl    = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _adresseCtrl   = TextEditingController();
  final _telCtrl       = TextEditingController();
  final _emailCtrl     = TextEditingController();

  String? _logoUrl;
  String? _signatureUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sloganCtrl.dispose();
    _descCtrl.dispose();
    _adresseCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await CompanySettingsService.getMySettings();
    if (mounted) {
      setState(() {
        _settings = s;
        if (s != null) {
          _nameCtrl.text    = s.companyName;
          _sloganCtrl.text  = s.slogan ?? '';
          _descCtrl.text    = s.description ?? '';
          _adresseCtrl.text = s.adresse ?? '';
          _telCtrl.text     = s.telephone ?? '';
          _emailCtrl.text   = s.email ?? '';
          _logoUrl          = s.logoUrl;
          _signatureUrl     = s.signatureUrl;
        }
        _loading = false;
      });
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final bytes = result.files.single.bytes!;
    final ext = result.files.single.extension ?? 'png';
    setState(() => _saving = true);
    try {
      final url = await CompanySettingsService.uploadLogo(bytes, ext);
      setState(() {
        _logoUrl = url;
        _saving  = false;
      });
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) _showError('Erreur upload logo : $e');
    }
  }

  Future<void> _pickSignature() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final bytes = result.files.single.bytes!;
    final ext = result.files.single.extension ?? 'png';
    setState(() => _saving = true);
    try {
      final url = await CompanySettingsService.uploadSignature(bytes, ext);
      setState(() {
        _signatureUrl = url;
        _saving       = false;
      });
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) _showError('Erreur upload signature : $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final updated = CompanySettings(
        id:           _settings?.id,
        userId:       uid,
        companyName:  _nameCtrl.text.trim(),
        slogan:       _sloganCtrl.text.trim().isEmpty ? null : _sloganCtrl.text.trim(),
        description:  _descCtrl.text.trim().isEmpty   ? null : _descCtrl.text.trim(),
        adresse:      _adresseCtrl.text.trim().isEmpty ? null : _adresseCtrl.text.trim(),
        telephone:    _telCtrl.text.trim().isEmpty    ? null : _telCtrl.text.trim(),
        email:        _emailCtrl.text.trim().isEmpty  ? null : _emailCtrl.text.trim(),
        logoUrl:      _logoUrl,
        signatureUrl: _signatureUrl,
      );
      final saved = await CompanySettingsService.save(updated);
      setState(() {
        _settings = saved;
        _saving   = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paramètres sauvegardés'),
            backgroundColor: AppColors.g600,
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) _showError('Erreur sauvegarde : $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres entreprise'),
        backgroundColor: AppColors.g700,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── Logo + Signature ───────────────────────────────
                    _SectionHeader('Identité visuelle'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ImageCard(
                            label: 'Logo',
                            url: _logoUrl,
                            onTap: _saving ? null : _pickLogo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ImageCard(
                            label: 'Signature / Cachet',
                            url: _signatureUrl,
                            onTap: _saving ? null : _pickSignature,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ─── Informations entreprise ────────────────────────
                    _SectionHeader('Informations entreprise'),
                    const SizedBox(height: 12),
                    _field(
                      ctrl: _nameCtrl,
                      label: 'Nom de l\'entreprise *',
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    _field(ctrl: _sloganCtrl, label: 'Slogan'),
                    const SizedBox(height: 12),
                    _field(ctrl: _descCtrl, label: 'Description', maxLines: 2),
                    const SizedBox(height: 12),
                    _field(ctrl: _adresseCtrl, label: 'Adresse'),
                    const SizedBox(height: 12),
                    _field(
                      ctrl: _telCtrl,
                      label: 'Téléphone',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      ctrl: _emailCtrl,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 28),

                    // ─── Bouton sauvegarder ─────────────────────────────
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.g700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Sauvegarde...' : 'Sauvegarder'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.g700,
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  final String label;
  final String? url;
  final VoidCallback? onTap;

  const _ImageCard({required this.label, this.url, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.s50,
          border: Border.all(color: AppColors.s200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (url != null && url!.isNotEmpty)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.network(
                    url!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, color: AppColors.s300),
                  ),
                ),
              )
            else
              const Icon(Icons.add_photo_alternate_outlined,
                  size: 36, color: AppColors.s300),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.s500,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              url != null ? 'Appuyer pour changer' : 'Appuyer pour ajouter',
              style: const TextStyle(fontSize: 9, color: AppColors.s300),
            ),
          ],
        ),
      ),
    );
  }
}
