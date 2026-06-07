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
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Vérifie le code OTP de récupération (connecte l'utilisateur)
  Future<bool> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    final res = await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery,
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
    // Le profil est créé automatiquement par le trigger on_auth_user_created
    // On attend un peu si nécessaire (délai trigger)
    for (var i = 0; i < 3; i++) {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (data != null) return UserProfile.fromMap(data);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    // Profil introuvable mais user connecté : retourner un profil minimal
    return UserProfile(
      id: user.id,
      email: user.email ?? '',
      nom: user.email?.split('@').first ?? 'Utilisateur',
      role: 'gestionnaire',
      createdAt: DateTime.now(),
    );
  }
}
