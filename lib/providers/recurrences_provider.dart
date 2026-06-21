import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recurrence.dart';
import '../services/recurrence_service.dart';

/// Liste des récurrences de l'utilisateur.
final recurrencesProvider = FutureProvider<List<Recurrence>>((ref) {
  return RecurrenceService().getAll();
});

/// Génère les factures récurrentes échues (exécuté une fois par session,
/// au montage du tableau de bord). Retourne le nombre de factures créées.
final recurrencesAutoGenProvider = FutureProvider<int>((ref) {
  return RecurrenceService().genererEchues();
});
