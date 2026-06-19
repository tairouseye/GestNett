enum ReminderSeverite { info, warning, danger }

enum ReminderType { visiteMedicale, visiteTerrain, suiviQualite, valorisation }

/// Rappel in-app calculé à la volée (pas stocké en base).
class Reminder {
  final String titre;
  final String sousTitre;
  final ReminderType type;
  final ReminderSeverite severite;
  final String? employeId; // pour naviguer vers /employes/:id
  final DateTime? date;

  const Reminder({
    required this.titre,
    required this.sousTitre,
    required this.type,
    required this.severite,
    this.employeId,
    this.date,
  });
}
