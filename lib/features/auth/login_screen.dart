import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

enum _Mode { login, signup, forgotStep1, forgotStep2 }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _Mode _mode = _Mode.login;
  bool _loading = false;
  String? _error;

  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _codeCtrl  = TextEditingController();

  String _forgotEmail = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _setMode(_Mode mode, {bool clearEmail = false}) => setState(() {
    _mode = mode;
    _error = null;
    if (clearEmail) _emailCtrl.clear();
    _passCtrl.clear();
  });

  // ── Connexion ──────────────────────────────────────────────────────────────

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Adresse email invalide');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Mot de passe : 6 caractères minimum');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final profile = await ref.read(authServiceProvider).signIn(
          email: email, password: pass);
      if (profile == null) {
        if (mounted) setState(() => _error = 'Email ou mot de passe incorrect.');
      } else {
        if (mounted) context.go('/');
      }
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // _signup géré dans _SignupCard

  // ── Mot de passe oublié — étape 1 : envoyer le code ───────────────────────

  Future<void> _sendResetCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Adresse email invalide');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).sendLoginOtp(email);
      if (mounted) {
        setState(() {
          _forgotEmail = email;
          _mode = _Mode.forgotStep2;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = _friendlyError(e);
        _loading = false;
      });
    }
  }


  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return 'Email ou mot de passe incorrect.\n(Si vous venez de vous inscrire, réessayez dans quelques secondes)';
    }
    if (msg.contains('already registered') || msg.contains('user already')) return 'Cet email est déjà utilisé.';
    if (msg.contains('rate limit') || msg.contains('too many') || msg.contains('over_email_send_rate_limit')) {
      return 'Limite d\'emails atteinte. Attendez quelques minutes avant de réessayer.';
    }
    if (msg.contains('user not found')) return 'Aucun compte avec cet email.';
    if (msg.contains('email not confirmed')) return 'Email non confirmé. Désactivez la confirmation dans Supabase.';
    if (msg.contains('retryablefetch') || msg.contains('network') || msg.contains('socketexception') || msg.contains('clientexception')) {
      return 'Erreur réseau. Vérifiez votre connexion et réessayez.\n(Détail: ${e.runtimeType})';
    }
    // Afficher l'erreur brute pour faciliter le diagnostic
    return '${e.runtimeType}: ${e.toString().replaceAll('AuthException', '').replaceAll('Exception:', '').trim()}';
  }

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
                const SizedBox(height: 36),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: switch (_mode) {
                    _Mode.login      => _buildLogin(),
                    _Mode.signup     => _buildSignup(),
                    _Mode.forgotStep1 => _buildForgotStep1(),
                    _Mode.forgotStep2 => _buildForgotStep2(),
                  },
                ),

                const SizedBox(height: 20),
                const _VersionText(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Carte Connexion ────────────────────────────────────────────────────────

  Widget _buildLogin() => _Card(
    key: const ValueKey('login'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Connexion',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        const Text('Bienvenue sur GesPro',
            style: TextStyle(color: AppColors.g500, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),

        _EmailField(_emailCtrl),
        const SizedBox(height: 12),
        _PasswordField(ctrl: _passCtrl, label: 'Mot de passe',
            onSubmit: _login),

        _ErrorBox(_error),
        const SizedBox(height: 8),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _setMode(_Mode.forgotStep1),
            child: const Text('Mot de passe oublié ?',
                style: TextStyle(color: AppColors.g500, fontSize: 12)),
          ),
        ),

        const SizedBox(height: 8),
        _SubmitButton(
          loading: _loading,
          label: 'Se connecter',
          icon: Icons.login,
          onPressed: _login,
        ),
        const SizedBox(height: 12),

        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Pas encore de compte ?',
              style: TextStyle(color: AppColors.s400, fontSize: 12)),
          TextButton(
            onPressed: () => _setMode(_Mode.signup),
            child: const Text('S\'inscrire',
                style: TextStyle(
                    color: AppColors.g400,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ],
    ),
  );

  // ── Carte Inscription ──────────────────────────────────────────────────────

  Widget _buildSignup() => _SignupCard(
    key: const ValueKey('signup'),
    emailCtrl: _emailCtrl,
    loading: _loading,
    error: _error,
    onSignup: (pass, confirm) async {
      final email = _emailCtrl.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        setState(() => _error = 'Adresse email invalide');
        return;
      }
      if (pass.length < 6) {
        setState(() => _error = 'Mot de passe : 6 caractères minimum');
        return;
      }
      if (pass != confirm) {
        setState(() => _error = 'Les mots de passe ne correspondent pas');
        return;
      }
      setState(() { _loading = true; _error = null; });
      try {
        await ref.read(authServiceProvider).signUp(email: email, password: pass);
        if (mounted) {
          _setMode(_Mode.login, clearEmail: true);
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Compte créé ! Connectez-vous maintenant.'),
              backgroundColor: AppColors.g600,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted) setState(() { _error = _friendlyError(e); _loading = false; });
      }
    },
    onBack: () => _setMode(_Mode.login, clearEmail: true),
  );

  // ── Carte Mot de passe oublié — étape 1 ───────────────────────────────────

  Widget _buildForgotStep1() => _Card(
    key: const ValueKey('forgot1'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackRow(onBack: () => _setMode(_Mode.login), title: 'Mot de passe oublié'),
        const SizedBox(height: 8),
        const Text(
          'Entrez votre email. Vous recevrez un code pour créer un nouveau mot de passe.',
          style: TextStyle(color: AppColors.s400, fontSize: 12),
        ),
        const SizedBox(height: 20),

        _EmailField(_emailCtrl, onSubmit: _sendResetCode),

        _ErrorBox(_error),
        const SizedBox(height: 20),

        _SubmitButton(
          loading: _loading,
          label: 'Recevoir le code',
          icon: Icons.send_outlined,
          onPressed: _sendResetCode,
        ),
      ],
    ),
  );

  // ── Mot de passe oublié — étape 2 : vérifier le code OTP ─────────────────

  Future<void> _verifyOtpAndLogin() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Entrez le code reçu par email');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final ok = await ref.read(authServiceProvider).verifyLoginOtp(
          email: _forgotEmail, token: code);
      if (!ok) {
        if (mounted) setState(() {
          _error = 'Code invalide ou expiré.';
          _loading = false;
        });
        return;
      }
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) setState(() { _error = _friendlyError(e); _loading = false; });
    }
  }

  // ── Carte Mot de passe oublié — étape 2 ───────────────────────────────────

  Widget _buildForgotStep2() => _Card(
    key: const ValueKey('forgot2'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackRow(onBack: () => _setMode(_Mode.forgotStep1), title: 'Vérification'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.g50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.g100),
          ),
          child: Row(children: [
            const Icon(Icons.mark_email_read_outlined, color: AppColors.g600, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Code de vérification envoyé à\n$_forgotEmail',
                  style: const TextStyle(color: AppColors.g700, fontSize: 12)),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 8,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onFieldSubmitted: (_) => _verifyOtpAndLogin(),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
          decoration: const InputDecoration(
            labelText: 'Code reçu',
            counterText: '',
            hintText: 'Code reçu par email',
            hintStyle: TextStyle(letterSpacing: 0, fontSize: 16, color: AppColors.g300),
          ),
        ),
        _ErrorBox(_error),
        const SizedBox(height: 20),
        _SubmitButton(loading: _loading, label: 'Se connecter', icon: Icons.login, onPressed: _verifyOtpAndLogin),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _loading ? null : _sendResetCode,
            icon: const Icon(Icons.refresh, size: 14, color: AppColors.g500),
            label: const Text('Renvoyer le code', style: TextStyle(color: AppColors.g500, fontSize: 12)),
          ),
        ),
      ],
    ),
  );
}

// ── Widgets partagés ───────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({super.key, required this.child});

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
        ),
      ],
    ),
    padding: const EdgeInsets.all(24),
    child: child,
  );
}

class _BackRow extends StatelessWidget {
  final VoidCallback onBack;
  final String title;
  const _BackRow({required this.onBack, required this.title});

  @override
  Widget build(BuildContext context) => Row(children: [
    IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      onPressed: onBack,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    ),
    const SizedBox(width: 8),
    Text(title, style: Theme.of(context).textTheme.titleLarge),
  ]);
}

class _EmailField extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback? onSubmit;
  const _EmailField(this.ctrl, {this.onSubmit});

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    keyboardType: TextInputType.emailAddress,
    textInputAction: onSubmit != null ? TextInputAction.done : TextInputAction.next,
    onFieldSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
    decoration: const InputDecoration(
      labelText: 'Adresse email',
      prefixIcon: Icon(Icons.email_outlined),
      hintText: 'votre@email.com',
    ),
  );
}

class _PasswordField extends StatefulWidget {
  final TextEditingController ctrl;
  final String label;
  final VoidCallback? onSubmit;
  final bool disableAutofill;
  const _PasswordField({
    required this.ctrl,
    required this.label,
    this.onSubmit,
    this.disableAutofill = false,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.ctrl,
    obscureText: _obscure,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: widget.disableAutofill ? const [] : const [AutofillHints.password],
    textInputAction: widget.onSubmit != null
        ? TextInputAction.done : TextInputAction.next,
    onFieldSubmitted: widget.onSubmit != null ? (_) => widget.onSubmit!() : null,
    decoration: InputDecoration(
      labelText: widget.label,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        icon: Icon(_obscure
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    ),
  );
}

class _SubmitButton extends StatelessWidget {
  final bool loading;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _SubmitButton({
    required this.loading,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: ElevatedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white))
          : Icon(icon, size: 18),
      label: Text(loading ? 'Chargement...' : label),
    ),
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
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(error!,
                style: const TextStyle(color: AppColors.red, fontSize: 13)),
          ),
        ]),
      ),
    );
  }
}

class _LogoBlock extends StatelessWidget {
  const _LogoBlock();

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 96, height: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
      ),
    ),
    const SizedBox(height: 16),
    RichText(
      text: const TextSpan(children: [
        TextSpan(
          text: 'Ges',
          style: TextStyle(
              color: AppColors.white, fontSize: 30,
              fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        TextSpan(
          text: 'Pro',
          style: TextStyle(
              color: AppColors.g400, fontSize: 30,
              fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ]),
    ),
    const SizedBox(height: 4),
  ]);
}

// ── Carte Inscription (StatefulWidget isolé pour éviter l'autofill) ──────────

class _SignupCard extends StatefulWidget {
  final TextEditingController emailCtrl;
  final bool loading;
  final String? error;
  final Future<void> Function(String pass, String confirm) onSignup;
  final VoidCallback onBack;
  const _SignupCard({
    super.key,
    required this.emailCtrl,
    required this.loading,
    required this.error,
    required this.onSignup,
    required this.onBack,
  });

  @override
  State<_SignupCard> createState() => _SignupCardState();
}

class _SignupCardState extends State<_SignupCard> {
  // Contrôleurs locaux : le navigateur ne les lie pas au formulaire de login
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Vider après que le navigateur ait éventuellement rempli
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passCtrl.clear();
      _confirmCtrl.clear();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) { _passCtrl.clear(); _confirmCtrl.clear(); }
    });
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BackRow(onBack: widget.onBack, title: 'Créer un compte'),
          const SizedBox(height: 20),

          _EmailField(widget.emailCtrl),
          const SizedBox(height: 12),
          _PasswordField(ctrl: _passCtrl, label: 'Mot de passe', disableAutofill: true),
          const SizedBox(height: 12),
          _PasswordField(
            ctrl: _confirmCtrl,
            label: 'Confirmer le mot de passe',
            disableAutofill: true,
            onSubmit: () => widget.onSignup(_passCtrl.text, _confirmCtrl.text),
          ),

          _ErrorBox(widget.error),
          const SizedBox(height: 20),

          _SubmitButton(
            loading: widget.loading,
            label: 'Créer mon compte',
            icon: Icons.person_add_outlined,
            onPressed: () => widget.onSignup(_passCtrl.text, _confirmCtrl.text),
          ),
          const SizedBox(height: 12),

          Center(
            child: TextButton(
              onPressed: widget.onBack,
              child: const Text('Déjà un compte ? Se connecter',
                  style: TextStyle(color: AppColors.g500, fontSize: 12)),
            ),
          ),
        ],
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
    'GesPro${_version.isNotEmpty ? ' v$_version' : ''}',
    style: const TextStyle(color: AppColors.g300, fontSize: 11),
  );
}
