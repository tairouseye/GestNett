import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class AuthService {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Connexion email + mot de passe
  Future<UserProfile?> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.user == null) return null;
    return _fetchOrCreateProfile(res.user!);
  }

  /// Inscription email + mot de passe
  Future<UserProfile?> signUp({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
    );
    if (res.user == null) return null;
    return _fetchOrCreateProfile(res.user!);
  }

  /// Envoie un code OTP pour réinitialiser le mot de passe
  Future<void> sendPasswordResetOtp(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
    );
  }

  /// Vérifie le code OTP de récupération (connecte l'utilisateur)
  Future<bool> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    final res = await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
    return res.user != null;
  }

  /// Met à jour le mot de passe de l'utilisateur connecté
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<UserProfile?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return _fetchOrCreateProfile(user);
  }

  Future<UserProfile?> _fetchOrCreateProfile(User user) async {
    var data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      // Créer automatiquement le profil si absent
      await _client.from('profiles').upsert({
        'id': user.id,
        'email': user.email ?? '',
        'nom': user.email?.split('@').first ?? 'Utilisateur',
        'role': 'gestionnaire',
        'created_at': DateTime.now().toIso8601String(),
      });
      data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
    }

    if (data == null) return null;
    return UserProfile.fromMap(data);
  }
}
