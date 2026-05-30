import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class AuthService {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  Future<void> sendOtp(String email) async {
    await _client.auth.signInWithOtp(email: email);
  }

  Future<UserProfile?> verifyOtp({
    required String email,
    required String token,
  }) async {
    final res = await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
    if (res.user == null) return null;
    return _fetchProfile(res.user!.id);
  }

  Future<UserProfile?> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.user == null) return null;
    return _fetchProfile(res.user!.id);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<UserProfile?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return _fetchProfile(user.id);
  }

  Future<UserProfile?> _fetchProfile(String uid) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (data == null) return null;
    return UserProfile.fromMap(data);
  }

  Future<void> createProfile({
    required String uid,
    required String email,
    required String nom,
    String role = 'gestionnaire',
  }) async {
    await _client.from('profiles').upsert({
      'id': uid,
      'email': email,
      'nom': nom,
      'role': role,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
