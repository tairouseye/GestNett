import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/employe.dart';
import '../models/reminder.dart';
import '../services/employe_service.dart';
import '../services/evaluation_service.dart';

/// Rappels in-app calculés à la volée à partir des données employés.
/// - Visites médicales de démarrage dues / en retard
/// - Visites terrain (J+15 d'une affectation sans évaluation superviseur)
/// - Employés « à suivre » (note d'évaluation faible) → alerte N+1
final remindersProvider = FutureProvider<List<Reminder>>((ref) async {
  final employeService = EmployeService();
  final employes = await employeService.getAll();
  final reminders = <Reminder>[];
  final fmt = DateFormat('dd/MM/yyyy');

  for (final e in employes) {
    if (e.statut == EmployeStatut.inactif) continue;

    // Visite médicale de démarrage
    if (!e.visiteMedicaleFaite) {
      final enRetard = e.visiteMedicaleEnRetard;
      reminders.add(Reminder(
        titre: 'Visite médicale — ${e.nomComplet}',
        sousTitre: enRetard
            ? 'En retard (échéance ${fmt.format(e.visiteMedicaleEcheance)})'
            : 'À effectuer avant le ${fmt.format(e.visiteMedicaleEcheance)}',
        type: ReminderType.visiteMedicale,
        severite: enRetard ? ReminderSeverite.danger : ReminderSeverite.warning,
        employeId: e.id,
        date: e.visiteMedicaleEcheance,
      ));
    }

    // Alerte qualité : employé à suivre (note faible)
    if (e.aSuivre) {
      reminders.add(Reminder(
        titre: 'À suivre — ${e.nomComplet}',
        sousTitre: 'Note d\'évaluation faible : action requise du N+1'
            '${e.superviseurNom != null ? ' (${e.superviseurNom})' : ''}',
        type: ReminderType.suiviQualite,
        severite: ReminderSeverite.danger,
        employeId: e.id,
        date: DateTime.now(),
      ));
    }
  }

  // Visites terrain : affectations en cours dont J+15 est dépassé sans
  // évaluation superviseur enregistrée.
  final actives = await employeService.getAffectationsActives();
  final evalKeys = await EvaluationService().getSuperviseurEvalKeys();
  final now = DateTime.now();
  for (final a in actives) {
    final echeance = a.dateDebut.add(const Duration(days: 15));
    if (now.isAfter(echeance) && !evalKeys.contains('${a.employeId}:${a.marketId}')) {
      reminders.add(Reminder(
        titre: 'Visite terrain — ${a.employeNom ?? 'Employé'}',
        sousTitre: 'Marché ${a.marketNumero ?? ''} — évaluation superviseur à réaliser',
        type: ReminderType.visiteTerrain,
        severite: ReminderSeverite.warning,
        employeId: a.employeId,
        date: echeance,
      ));
    }
  }

  // Plus urgent d'abord (danger), puis par échéance croissante.
  reminders.sort((a, b) {
    final s = b.severite.index.compareTo(a.severite.index);
    if (s != 0) return s;
    return (a.date ?? DateTime(2100)).compareTo(b.date ?? DateTime(2100));
  });
  return reminders;
});

/// Nombre de rappels (pour le badge de la cloche).
final reminderCountProvider = Provider<int>((ref) {
  return ref.watch(remindersProvider).maybeWhen(
        data: (list) => list.length,
        orElse: () => 0,
      );
});
