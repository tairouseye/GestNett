import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Déconnecte automatiquement l'utilisateur après [timeout] d'inactivité.
class InactivityService {
  InactivityService._();
  static final _instance = InactivityService._();
  static InactivityService get instance => _instance;

  // Durée d'inactivité avant déconnexion
  static const timeout = Duration(minutes: 30);

  Timer? _timer;
  VoidCallback? _onTimeout;

  /// Démarre la surveillance — appeler après connexion.
  void start(VoidCallback onTimeout) {
    _onTimeout = onTimeout;
    _reset();
  }

  /// Réinitialise le timer — appeler à chaque interaction utilisateur.
  void _reset() {
    _timer?.cancel();
    _timer = Timer(timeout, _handleTimeout);
  }

  /// Enregistre une activité utilisateur (tap, scroll, etc.).
  void onUserActivity() {
    if (_timer != null) _reset();
  }

  void _handleTimeout() async {
    await Supabase.instance.client.auth.signOut();
    _onTimeout?.call();
    stop();
  }

  /// Arrête la surveillance — appeler à la déconnexion.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _onTimeout = null;
  }
}
