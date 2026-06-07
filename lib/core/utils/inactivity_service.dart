import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Déconnecte automatiquement après [_timeout] d'inactivité.
/// Un avertissement est affiché [_warningBefore] avant l'expiration.
class InactivityService {
  InactivityService._();
  static final _instance = InactivityService._();
  static InactivityService get instance => _instance;

  static const _timeout       = Duration(minutes: 30);
  static const _warningBefore = Duration(minutes: 2);

  Timer? _warningTimer;
  Timer? _logoutTimer;
  VoidCallback? _onTimeout;
  VoidCallback? _onWarning;

  bool _warningShown = false;

  /// Démarre la surveillance.
  /// [onTimeout] : appelé après déconnexion Supabase.
  /// [onWarning] : appelé pour afficher le dialogue d'avertissement.
  void start(VoidCallback onTimeout, {VoidCallback? onWarning}) {
    _onTimeout = onTimeout;
    _onWarning = onWarning;
    _reset();
  }

  /// Enregistre une activité utilisateur (tap, scroll…).
  void onUserActivity() {
    if (_logoutTimer != null) _reset();
  }

  /// Prolonge la session depuis le dialogue d'avertissement.
  void extendSession() {
    _warningShown = false;
    _reset();
  }

  void _reset() {
    _warningTimer?.cancel();
    _logoutTimer?.cancel();

    final warningDelay = _timeout - _warningBefore;

    _warningTimer = Timer(warningDelay, () {
      if (!_warningShown) {
        _warningShown = true;
        _onWarning?.call();
      }
    });

    _logoutTimer = Timer(_timeout, _handleTimeout);
  }

  Future<void> _handleTimeout() async {
    _warningShown = false;
    await Supabase.instance.client.auth.signOut();
    _onTimeout?.call();
    stop();
  }

  /// Déconnexion immédiate (depuis le dialogue ou le bouton Quitter).
  Future<void> forceLogout() async {
    stop();
    await Supabase.instance.client.auth.signOut();
    _onTimeout?.call();
  }

  /// Arrête la surveillance.
  void stop() {
    _warningTimer?.cancel();
    _logoutTimer?.cancel();
    _warningTimer = null;
    _logoutTimer  = null;
    _onTimeout    = null;
    _onWarning    = null;
    _warningShown = false;
  }
}
