enum MarketStatut { enAttente, enCours, termine, suspendu }

extension MarketStatutExt on MarketStatut {
  String get value => switch (this) {
    MarketStatut.enAttente => 'en_attente',
    MarketStatut.enCours   => 'en_cours',
    MarketStatut.termine   => 'termine',
    MarketStatut.suspendu  => 'suspendu',
  };

  String get label => switch (this) {
    MarketStatut.enAttente => 'En attente',
    MarketStatut.enCours   => 'En cours',
    MarketStatut.termine   => 'Terminé',
    MarketStatut.suspendu  => 'Suspendu',
  };

  static MarketStatut fromValue(String v) => switch (v) {
    'en_cours'  => MarketStatut.enCours,
    'termine'   => MarketStatut.termine,
    'suspendu'  => MarketStatut.suspendu,
    _           => MarketStatut.enAttente,
  };
}

class Market {
  final String id;
  final String numero;
  final String clientId;
  final String? clientNom; // joint depuis la table clients
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final String? description;
  final double montantTotal;
  final MarketStatut statut;
  final DateTime createdAt;

  const Market({
    required this.id,
    required this.numero,
    required this.clientId,
    this.clientNom,
    this.dateDebut,
    this.dateFin,
    this.description,
    required this.montantTotal,
    required this.statut,
    required this.createdAt,
  });

  factory Market.fromMap(Map<String, dynamic> m) => Market(
    id: m['id'] as String,
    numero: m['numero'] as String,
    clientId: m['client_id'] as String,
    clientNom: m['clients'] != null
        ? (m['clients'] as Map<String, dynamic>)['nom'] as String?
        : null,
    dateDebut: m['date_debut'] != null
        ? DateTime.parse(m['date_debut'] as String) : null,
    dateFin: m['date_fin'] != null
        ? DateTime.parse(m['date_fin'] as String) : null,
    description: m['description'] as String?,
    montantTotal: (m['montant_total'] as num?)?.toDouble() ?? 0,
    statut: MarketStatutExt.fromValue(m['statut'] as String? ?? 'en_attente'),
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  Map<String, dynamic> toInsertMap() => {
    'numero': numero,
    'client_id': clientId,
    if (dateDebut != null) 'date_debut': dateDebut!.toIso8601String().substring(0, 10),
    if (dateFin != null)   'date_fin':   dateFin!.toIso8601String().substring(0, 10),
    if (description != null) 'description': description,
    'montant_total': montantTotal.round(),
    'statut': statut.value,
  };
}
