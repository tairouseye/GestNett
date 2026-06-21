enum ReminderSeverite { info, warning, danger }

enum ReminderType {
  visiteMedicale,
  visiteTerrain,
  suiviQualite,
  valorisation,
  echeanceMarche,
}

/// Rappel in-app calculé à la volée (pas stocké en base).
class Reminder {
  final String titre;
  final String sousTitre;
  final ReminderType type;
  final ReminderSeverite severite;
  final String? employeId; // pour naviguer vers /employes/:id
  final String? route;     // route de navigation explicite (sinon /employes/:id)
  final DateTime? date;

  const Reminder({
    required this.titre,
    required this.sousTitre,
    required this.type,
    required this.severite,
    this.employeId,
    this.route,
    this.date,
  });

  /// Route de navigation au tap (priorité à [route], sinon la fiche employé).
  String? get target => route ?? (employeId != null ? '/employes/$employeId' : null);
}
