enum EvaluationType { superviseur, client }

extension EvaluationTypeExt on EvaluationType {
  String get value => switch (this) {
    EvaluationType.superviseur => 'superviseur',
    EvaluationType.client      => 'client',
  };
  String get label => switch (this) {
    EvaluationType.superviseur => 'Superviseur',
    EvaluationType.client      => 'Client',
  };
  static EvaluationType fromValue(String v) =>
      v == 'client' ? EvaluationType.client : EvaluationType.superviseur;
}

/// Un critère d'évaluation (case à cocher pondérée).
class EvalCritere {
  final String key;
  final String label;
  final int poids;
  const EvalCritere(this.key, this.label, this.poids);
}

/// Grilles prédéfinies. Chaque critère est une case à cocher : cochée =
/// "conforme/satisfaisant" → ses points comptent. Score normalisé sur 20.
class EvaluationCriteres {
  static const superviseur = [
    EvalCritere('ponctualite',   'Ponctualité / assiduité', 2),
    EvalCritere('tenue',         'Présentation / tenue correcte', 2),
    EvalCritere('qualite',       'Qualité du travail effectué', 3),
    EvalCritere('consignes',     'Respect des consignes et du planning', 2),
    EvalCritere('comportement',  'Comportement / politesse', 2),
    EvalCritere('hygiene',       'Hygiène & sécurité respectées', 2),
    EvalCritere('materiel',      'Bon usage du matériel', 1),
  ];

  static const client = [
    EvalCritere('satisfaction',  'Satisfaction générale', 3),
    EvalCritere('ponctualite',   'Ponctualité de l\'employé', 2),
    EvalCritere('qualite',       'Qualité de la prestation', 3),
    EvalCritere('comportement',  'Comportement & courtoisie', 2),
    EvalCritere('discretion',    'Discrétion / confiance', 2),
    EvalCritere('recommander',   'Recommanderiez-vous cet employé ?', 2),
  ];

  static List<EvalCritere> forType(EvaluationType t) =>
      t == EvaluationType.client ? client : superviseur;

  /// Score /20 à partir des cases cochées.
  static double score(EvaluationType t, Map<String, bool> reponses) {
    final criteres = forType(t);
    final total = criteres.fold<int>(0, (s, c) => s + c.poids);
    if (total == 0) return 0;
    final obtenu = criteres
        .where((c) => reponses[c.key] == true)
        .fold<int>(0, (s, c) => s + c.poids);
    return obtenu / total * 20;
  }
}

/// Seuil en dessous duquel la note est jugée faible (action requise).
const double kNoteFaibleSeuil = 10.0;

/// Note pondérée finale : 40% superviseur + 60% client.
/// Si une seule évaluation existe, on retourne celle-ci (note partielle).
double? noteFinale({double? scoreSuperviseur, double? scoreClient}) {
  if (scoreSuperviseur != null && scoreClient != null) {
    return 0.4 * scoreSuperviseur + 0.6 * scoreClient;
  }
  return scoreSuperviseur ?? scoreClient;
}

class Evaluation {
  final String id;
  final String employeId;
  final String? marketId;
  final String? marketNumero; // dénormalisé via join
  final EvaluationType type;
  final DateTime date;
  final Map<String, bool> reponses;
  final double score; // /20
  final DateTime createdAt;

  const Evaluation({
    required this.id,
    required this.employeId,
    this.marketId,
    this.marketNumero,
    required this.type,
    required this.date,
    required this.reponses,
    required this.score,
    required this.createdAt,
  });

  factory Evaluation.fromMap(Map<String, dynamic> m) {
    final raw = (m['reponses'] as Map?) ?? {};
    return Evaluation(
      id:        m['id'] as String,
      employeId: m['employe_id'] as String,
      marketId:  m['market_id'] as String?,
      marketNumero: m['markets'] != null
          ? (m['markets'] as Map<String, dynamic>)['numero'] as String?
          : null,
      type:  EvaluationTypeExt.fromValue(m['type'] as String? ?? 'superviseur'),
      date:  DateTime.parse(m['date'] as String),
      reponses: raw.map((k, v) => MapEntry(k as String, v == true)),
      score: (m['score'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'employe_id': employeId,
    if (marketId != null) 'market_id': marketId,
    'type': type.value,
    'date': date.toIso8601String().substring(0, 10),
    'reponses': reponses,
    'score': score,
  };
}
