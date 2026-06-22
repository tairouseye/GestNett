import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/utils/formatters.dart';
import '../models/employe.dart';
import '../models/market.dart';
import '../models/reminder.dart';
import '../services/employe_service.dart';
import '../services/evaluation_service.dart';
import '../services/invoice_service.dart';
import '../services/market_service.dart';

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

    // Visite médicale de démarrage (uniquement si le poste l'exige)
    if (e.visiteMedicaleAFaire) {
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

    // Valorisation : employé excellent à mettre en avant
    if (e.aValoriser) {
      reminders.add(Reminder(
        titre: 'À valoriser — ${e.nomComplet}',
        sousTitre: 'Excellente évaluation : féliciter / récompenser'
            '${e.superviseurNom != null ? ' (${e.superviseurNom})' : ''}',
        type: ReminderType.valorisation,
        severite: ReminderSeverite.info,
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

  // Échéances de marchés : « en cours » dont la date de fin approche (≤ 7 j) ou
  // est dépassée.
  final markets = await MarketService().getAll();
  for (final m in markets) {
    if (m.statut != MarketStatut.enCours || m.dateFin == null) continue;
    final jours = m.dateFin!.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (jours <= 7) {
      final depasse = jours < 0;
      reminders.add(Reminder(
        titre: 'Échéance marché — ${m.numero}',
        sousTitre: depasse
            ? 'Terminé depuis ${-jours} j (${m.clientNom ?? ''}) — à clôturer/renouveler'
            : (jours == 0
                ? 'Se termine aujourd\'hui (${m.clientNom ?? ''})'
                : 'Se termine dans $jours j (${m.clientNom ?? ''})'),
        type: ReminderType.echeanceMarche,
        severite: depasse ? ReminderSeverite.danger : ReminderSeverite.warning,
        route: '/markets/${m.id}',
        date: m.dateFin,
      ));
    }
  }

  // Factures en retard : définitives non soldées dont l'échéance est dépassée.
  final unpaid = await InvoiceService().getUnpaid();
  for (final u in unpaid) {
    if (u.joursRetard > 0) {
      reminders.add(Reminder(
        titre: 'Facture en retard — ${u.invoice.numero}',
        sousTitre: '${u.invoice.clientNom ?? ''} · ${Formatters.fcfa(u.restant)} '
            'en retard de ${u.joursRetard} j',
        type: ReminderType.factureEnRetard,
        severite: ReminderSeverite.danger,
        route: '/invoices/${u.invoice.id}',
        date: u.invoice.echeance,
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
