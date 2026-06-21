enum Frequence { mensuelle, trimestrielle, annuelle }

extension FrequenceExt on Frequence {
  String get value => switch (this) {
    Frequence.mensuelle     => 'mensuelle',
    Frequence.trimestrielle => 'trimestrielle',
    Frequence.annuelle      => 'annuelle',
  };

  String get label => switch (this) {
    Frequence.mensuelle     => 'Mensuelle',
    Frequence.trimestrielle => 'Trimestrielle',
    Frequence.annuelle      => 'Annuelle',
  };

  /// Nombre de mois entre deux générations.
  int get mois => switch (this) {
    Frequence.mensuelle     => 1,
    Frequence.trimestrielle => 3,
    Frequence.annuelle      => 12,
  };

  static Frequence fromValue(String v) => switch (v) {
    'trimestrielle' => Frequence.trimestrielle,
    'annuelle'      => Frequence.annuelle,
    _               => Frequence.mensuelle,
  };
}

class Recurrence {
  final String id;
  final String marketId;
  final String? marketNumero;
  final String clientId;
  final String? clientNom;
  final double montantHt;
  final double tvaPct;
  final Frequence frequence;
  final int jourDuMois;
  final String typeFacture; // 'proforma' | 'definitive'
  final String? libelle;
  final bool actif;
  final DateTime prochaineDate;
  final DateTime? derniereGeneration;
  final DateTime createdAt;

  const Recurrence({
    required this.id,
    required this.marketId,
    this.marketNumero,
    required this.clientId,
    this.clientNom,
    required this.montantHt,
    this.tvaPct = 18.0,
    this.frequence = Frequence.mensuelle,
    this.jourDuMois = 1,
    this.typeFacture = 'definitive',
    this.libelle,
    this.actif = true,
    required this.prochaineDate,
    this.derniereGeneration,
    required this.createdAt,
  });

  double get totalTtc => montantHt * (1 + tvaPct / 100);

  bool get estEchue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return actif && !prochaineDate.isAfter(today);
  }

  factory Recurrence.fromMap(Map<String, dynamic> m) => Recurrence(
    id: m['id'] as String,
    marketId: m['market_id'] as String,
    marketNumero: m['markets'] != null
        ? (m['markets'] as Map<String, dynamic>)['numero'] as String?
        : null,
    clientId: m['client_id'] as String,
    clientNom: m['clients'] != null
        ? (m['clients'] as Map<String, dynamic>)['nom'] as String?
        : null,
    montantHt: (m['montant_ht'] as num?)?.toDouble() ?? 0,
    tvaPct: (m['tva_pct'] as num?)?.toDouble() ?? 18,
    frequence: FrequenceExt.fromValue(m['frequence'] as String? ?? 'mensuelle'),
    jourDuMois: (m['jour_du_mois'] as num?)?.toInt() ?? 1,
    typeFacture: m['type_facture'] as String? ?? 'definitive',
    libelle: m['libelle'] as String?,
    actif: m['actif'] as bool? ?? true,
    prochaineDate: DateTime.parse(m['prochaine_date'] as String),
    derniereGeneration: m['derniere_generation'] != null
        ? DateTime.parse(m['derniere_generation'] as String)
        : null,
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  Map<String, dynamic> toInsertMap() => {
    'market_id': marketId,
    'client_id': clientId,
    'montant_ht': montantHt.round(),
    'tva_pct': tvaPct,
    'frequence': frequence.value,
    'jour_du_mois': jourDuMois,
    'type_facture': typeFacture,
    if (libelle != null && libelle!.isNotEmpty) 'libelle': libelle,
    'actif': actif,
    'prochaine_date': prochaineDate.toIso8601String().substring(0, 10),
    if (derniereGeneration != null)
      'derniere_generation': derniereGeneration!.toIso8601String().substring(0, 10),
  };
}
