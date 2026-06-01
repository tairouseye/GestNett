import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl  = TextEditingController();
  bool _loading  = false;
  bool _codeSent = false;
  String? _error;
  String  _email = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ── Étape 1 : envoyer le code ──────────────────────────────────────────────

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Adresse email invalide');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).sendOtp(email);
      if (mounted) setState(() { _codeSent = true; _email = email; });
    } catch (e) {
      if (mounted) setState(() => _error = 'Impossible d\'envoyer le code. Vérifiez l\'email.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Étape 2 : vérifier le code ─────────────────────────────────────────────

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Entrez le code reçu par email');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final profile = await ref.read(authServiceProvider).verifyOtp(
        email: _email,
        token: code,
      );
      if (profile == null) {
        if (mounted) setState(() => _error = 'Code invalide ou expiré. Renvoyez un nouveau code.');
      } else {
        if (mounted) context.go('/');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Code invalide ou expiré.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _back() => setState(() {
    _codeSent = false;
    _codeCtrl.clear();
    _error = null;
  });

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.g900,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _LogoBlock(),
                const SizedBox(height: 40),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.1, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _codeSent
                      ? _CodeCard(
                          key: const ValueKey('code'),
                          email: _email,
                          ctrl: _codeCtrl,
                          loading: _loading,
                          error: _error,
                          onVerify: _verifyCode,
                          onResend: _sendCode,
                          onBack: _back,
                        )
                      : _EmailCard(
                          key: const ValueKey('email'),
                          ctrl: _emailCtrl,
                          loading: _loading,
                          error: _error,
                          onSend: _sendCode,
                        ),
                ),

                const SizedBox(height: 24),
                const _VersionText(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Étape 1 : saisie email ────────────────────────────────────────────────────

class _EmailCard extends StatelessWidget {
  final TextEditingController ctrl;
  final bool loading;
  final String? error;
  final VoidCallback onSend;
  const _EmailCard({super.key, required this.ctrl, required this.loading,
      required this.error, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Connexion',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          const Text(
            'Accès réservé au personnel D2SERVICES',
            style: TextStyle(color: AppColors.g500, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSend(),
            decoration: const InputDecoration(
              labelText: 'Adresse email',
              prefixIcon: Icon(Icons.email_outlined),
              hintText: 'votre@email.com',
            ),
          ),

          _ErrorBox(error),
          const SizedBox(height: 24),

          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: loading ? null : onSend,
              icon: loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.send_outlined, size: 18),
              label: Text(loading ? 'Envoi...' : 'Recevoir le code'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Étape 2 : saisie code OTP ─────────────────────────────────────────────────

class _CodeCard extends StatelessWidget {
  final String email;
  final TextEditingController ctrl;
  final bool loading;
  final String? error;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onBack;
  const _CodeCard({super.key, required this.email, required this.ctrl,
      required this.loading, required this.error, required this.onVerify,
      required this.onResend, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text('Vérification',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.g50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.g100),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_email_read_outlined,
                    color: AppColors.g600, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          color: AppColors.g700, fontSize: 13),
                      children: [
                        const TextSpan(text: 'Code envoyé à\n'),
                        TextSpan(
                          text: email,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.g900),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 8,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 10),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onVerify(),
            decoration: const InputDecoration(
              hintText: '00000000',
              counterText: '',
              hintStyle: TextStyle(
                  letterSpacing: 10,
                  fontSize: 24,
                  color: AppColors.g300),
            ),
          ),

          _ErrorBox(error),
          const SizedBox(height: 20),

          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: loading ? null : onVerify,
              icon: loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(loading ? 'Vérification...' : 'Se connecter'),
            ),
          ),
          const SizedBox(height: 12),

          Center(
            child: TextButton.icon(
              onPressed: loading ? null : onResend,
              icon: const Icon(Icons.refresh, size: 16,
                  color: AppColors.g600),
              label: const Text('Renvoyer un code',
                  style: TextStyle(color: AppColors.g600, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets partagés ──────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 24,
          offset: const Offset(0, 8),
        )
      ],
    ),
    padding: const EdgeInsets.all(24),
    child: child,
  );
}

class _ErrorBox extends StatelessWidget {
  final String? error;
  const _ErrorBox(this.error);

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(error!,
                  style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionText extends StatefulWidget {
  const _VersionText();

  @override
  State<_VersionText> createState() => _VersionTextState();
}

class _VersionTextState extends State<_VersionText> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) => Text(
    'CleanGest Sénégal${_version.isNotEmpty ? ' v$_version' : ''}',
    style: const TextStyle(color: AppColors.g300, fontSize: 11),
  );
}

class _LogoBlock extends StatelessWidget {
  const _LogoBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.g700, AppColors.g400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.g500.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: const Center(
              child: Text('🧹', style: TextStyle(fontSize: 36))),
        ),
        const SizedBox(height: 16),
        RichText(
          text: const TextSpan(children: [
            TextSpan(
              text: 'Clean',
              style: TextStyle(
                  color: AppColors.white, fontSize: 30,
                  fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            TextSpan(
              text: 'Gest',
              style: TextStyle(
                  color: AppColors.g400, fontSize: 30,
                  fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        const Text('D2SERVICES · Dakar',
            style: TextStyle(color: AppColors.g300, fontSize: 12)),
      ],
    );
  }
}
