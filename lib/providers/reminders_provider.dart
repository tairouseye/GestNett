import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/employe.dart';
import '../models/reminder.dart';
import '../services/employe_service.dart';

/// Rappels in-app calculés à la volée à partir des données employés.
/// Étape 1 : visites médicales de démarrage dues / en retard.
final remindersProvider = FutureProvider<List<Reminder>>((ref) async {
  final employes = await EmployeService().getAll();
  final reminders = <Reminder>[];

  for (final e in employes) {
    if (e.statut == EmployeStatut.inactif) continue;
    if (!e.visiteMedicaleFaite) {
      final enRetard = e.visiteMedicaleEnRetard;
      final echeance = DateFormat('dd/MM/yyyy').format(e.visiteMedicaleEcheance);
      reminders.add(Reminder(
        titre: 'Visite médicale — ${e.nomComplet}',
        sousTitre: enRetard
            ? 'En retard (échéance $echeance)'
            : 'À effectuer avant le $echeance',
        type: ReminderType.visiteMedicale,
        severite: enRetard ? ReminderSeverite.danger : ReminderSeverite.warning,
        employeId: e.id,
        date: e.visiteMedicaleEcheance,
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
