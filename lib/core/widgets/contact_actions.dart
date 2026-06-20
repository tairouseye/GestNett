import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';

/// Boutons de contact rapide (appel / SMS / WhatsApp / email).
/// Masque automatiquement les canaux indisponibles.
class ContactActions extends StatelessWidget {
  final String? telephone;
  final String? email;
  const ContactActions({super.key, this.telephone, this.email});

  String get _tel => (telephone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
  String get _waNum => (telephone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  String get _mail => (email ?? '').trim();

  Future<void> _launch(String uri) async {
    await launchUrl(Uri.parse(uri), mode: LaunchMode.platformDefault);
  }

  @override
  Widget build(BuildContext context) {
    final hasTel = _tel.isNotEmpty;
    final hasMail = _mail.isNotEmpty;
    if (!hasTel && !hasMail) return const SizedBox.shrink();
    return Row(
      children: [
        if (hasTel) _btn(Icons.call, 'Appeler', AppColors.g600, () => _launch('tel:$_tel')),
        if (hasTel) _btn(Icons.sms_outlined, 'SMS', AppColors.blue, () => _launch('sms:$_tel')),
        if (hasTel && _waNum.isNotEmpty)
          _btn(Icons.chat, 'WhatsApp', const Color(0xFF25D366), () => _launch('https://wa.me/$_waNum')),
        if (hasMail) _btn(Icons.email_outlined, 'Email', AppColors.orange, () => _launch('mailto:$_mail')),
      ],
    );
  }

  Widget _btn(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            ),
          ),
        ),
      );
}
