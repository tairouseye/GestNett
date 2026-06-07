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

  // En-tête
  final _nameCtrl    = TextEditingController();
  final _sloganCtrl  = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _tel1Ctrl    = TextEditingController();
  final _tel2Ctrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();

  // Bas de page légal
  final _nineaCtrl   = TextEditingController();
  final _rccmCtrl    = TextEditingController();
  final _ibanCtrl    = TextEditingController();
  final _banqueCtrl  = TextEditingController();

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
    _tel1Ctrl.dispose();
    _tel2Ctrl.dispose();
    _emailCtrl.dispose();
    _nineaCtrl.dispose();
    _rccmCtrl.dispose();
    _ibanCtrl.dispose();
    _banqueCtrl.dispose();
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
          _tel1Ctrl.text    = s.telephone ?? '';
          _tel2Ctrl.text    = s.telephone2 ?? '';
          _emailCtrl.text   = s.email ?? '';
          _nineaCtrl.text   = s.ninea ?? '';
          _rccmCtrl.text    = s.rccm ?? '';
          _ibanCtrl.text    = s.iban ?? '';
          _banqueCtrl.text  = s.nomBanque ?? '';
          _logoUrl          = s.logoUrl;
          _signatureUrl     = s.signatureUrl;
        }
        _loading = false;
      });
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final bytes = result.files.single.bytes!;
    final ext   = result.files.single.extension ?? 'png';
    setState(() => _saving = true);
    try {
      final url = await CompanySettingsService.uploadLogo(bytes, ext);
      setState(() { _logoUrl = url; _saving = false; });
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) _showError('Erreur upload logo : $e');
    }
  }

  Future<void> _pickSignature() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final bytes = result.files.single.bytes!;
    final ext   = result.files.single.extension ?? 'png';
    setState(() => _saving = true);
    try {
      final url = await CompanySettingsService.uploadSignature(bytes, ext);
      setState(() { _signatureUrl = url; _saving = false; });
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
        id:             _settings?.id,
        userId:         uid,
        companyName:    _nameCtrl.text.trim(),
        slogan:         _v(_sloganCtrl),
        description:    _v(_descCtrl),
        adresse:        _v(_adresseCtrl),
        telephone:      _v(_tel1Ctrl),
        telephone2:     _v(_tel2Ctrl),
        email:          _v(_emailCtrl),
        ninea:     _v(_nineaCtrl),
        rccm:      _v(_rccmCtrl),
        iban:      _v(_ibanCtrl),
        nomBanque: _v(_banqueCtrl),
        logoUrl:        _logoUrl,
        signatureUrl:   _signatureUrl,
      );
      final saved = await CompanySettingsService.save(updated);
      setState(() { _settings = saved; _saving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres sauvegardés'), backgroundColor: AppColors.g600),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) _showError('Erreur sauvegarde : $e');
    }
  }

  String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

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
                    // ── Identité visuelle ──────────────────────────────────
                    _SectionHeader('Identité visuelle', Icons.image_outlined),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _ImageCard(label: 'Logo', url: _logoUrl, onTap: _saving ? null : _pickLogo)),
                      const SizedBox(width: 12),
                      Expanded(child: _ImageCard(label: 'Signature / Cachet', url: _signatureUrl, onTap: _saving ? null : _pickSignature)),
                    ]),
                    const SizedBox(height: 24),

                    // ── En-tête facture ────────────────────────────────────
                    _SectionHeader('En-tête de facture', Icons.article_outlined),
                    const SizedBox(height: 4),
                    const Text('Ces informations apparaissent en haut de chaque facture.',
                        style: TextStyle(fontSize: 12, color: AppColors.s400)),
                    const SizedBox(height: 12),
                    _field(
                      ctrl: _nameCtrl,
                      label: 'Nom de l\'entreprise *',
                      hint: 'Ex: D2SERVICES',
                      bold: true,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    _field(ctrl: _sloganCtrl, label: 'Slogan', hint: 'Ex: Solutions professionnelles de nettoyage'),
                    const SizedBox(height: 12),
                    _field(ctrl: _descCtrl, label: 'Services / Description', hint: 'Ex: Nettoyage industriel, BTP, placement de personnel...', maxLines: 2),
                    const SizedBox(height: 12),
                    _field(ctrl: _adresseCtrl, label: 'Adresse', hint: 'Ex: Ouakam Tagolou – Dakar, Sénégal', prefixIcon: Icons.location_on_outlined),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _field(ctrl: _tel1Ctrl, label: 'Téléphone 1', hint: '(+221) 77 000 00 00', keyboardType: TextInputType.phone, prefixIcon: Icons.phone_outlined)),
                      const SizedBox(width: 12),
                      Expanded(child: _field(ctrl: _tel2Ctrl, label: 'Téléphone 2', hint: 'Optionnel', keyboardType: TextInputType.phone, prefixIcon: Icons.phone_outlined)),
                    ]),
                    const SizedBox(height: 12),
                    _field(ctrl: _emailCtrl, label: 'Email', hint: 'contact@entreprise.sn', keyboardType: TextInputType.emailAddress, prefixIcon: Icons.email_outlined),
                    const SizedBox(height: 24),

                    // ── Bas de page facture ────────────────────────────────
                    _SectionHeader('Bas de page de facture', Icons.receipt_long_outlined),
                    const SizedBox(height: 4),
                    const Text('Informations légales affichées en bas de chaque facture.',
                        style: TextStyle(fontSize: 12, color: AppColors.s400)),
                    const SizedBox(height: 12),
                    _field(ctrl: _nineaCtrl, label: 'NINEA', hint: 'Ex: 123456789 2Z3', prefixIcon: Icons.tag_outlined),
                    const SizedBox(height: 12),
                    _field(ctrl: _rccmCtrl, label: 'RCCM', hint: 'Ex: SN DKR 2018 B 12345', prefixIcon: Icons.business_outlined),
                    const SizedBox(height: 12),
                    _field(ctrl: _banqueCtrl, label: 'Nom de la banque', hint: 'Ex: Ecobank, CBAO, BHS...', prefixIcon: Icons.account_balance_outlined),
                    const SizedBox(height: 12),
                    _field(ctrl: _ibanCtrl, label: 'IBAN / N° de compte', hint: 'Ex: SN28 0100 1234 5678 9012 3456 789', prefixIcon: Icons.credit_card_outlined),
                    const SizedBox(height: 32),

                    // ── Bouton sauvegarder ─────────────────────────────────
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.g700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Sauvegarde...' : 'Sauvegarder'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    IconData? prefixIcon,
    bool bold = false,
  }) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.s300),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionHeader(this.text, this.icon);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: AppColors.g700),
    const SizedBox(width: 6),
    Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.g700)),
  ]);
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
                  child: Image.network(url!, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: AppColors.s300)),
                ),
              )
            else
              const Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.s300),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.s500, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(url != null ? 'Appuyer pour changer' : 'Appuyer pour ajouter',
                style: const TextStyle(fontSize: 9, color: AppColors.s300)),
          ],
        ),
      ),
    );
  }
}
