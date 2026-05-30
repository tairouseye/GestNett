import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((_) => AuthService());

// Stream de l'état d'auth Supabase
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Provider du profil de l'utilisateur connecté
final currentProfileProvider = FutureProvider<UserProfile?>((ref) {
  ref.watch(authStateProvider); // se recalcule quand l'auth change
  return ref.watch(authServiceProvider).getProfile();
});

// Booléen simple : est-on connecté ?
final isAuthenticatedProvider = Provider<bool>((ref) {
  final state = ref.watch(authStateProvider);
  return state.when(
    data: (s) => s.session != null,
    loading: () => false,
    error: (_, __) => false,
  );
});
