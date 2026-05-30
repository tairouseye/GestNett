enum ExpenseType { salaires, produits, transport, carburant, materiel, divers }

extension ExpenseTypeExt on ExpenseType {
  String get value => switch (this) {
    ExpenseType.salaires  => 'salaires',
    ExpenseType.produits  => 'produits',
    ExpenseType.transport => 'transport',
    ExpenseType.carburant => 'carburant',
    ExpenseType.materiel  => 'materiel',
    ExpenseType.divers    => 'divers',
  };

  String get label => switch (this) {
    ExpenseType.salaires  => 'Salaires',
    ExpenseType.produits  => 'Produits nettoyage',
    ExpenseType.transport => 'Transport',
    ExpenseType.carburant => 'Carburant',
    ExpenseType.materiel  => 'Matériel',
    ExpenseType.divers    => 'Divers',
  };

  static ExpenseType fromValue(String v) => switch (v) {
    'produits'  => ExpenseType.produits,
    'transport' => ExpenseType.transport,
    'carburant' => ExpenseType.carburant,
    'materiel'  => ExpenseType.materiel,
    'divers'    => ExpenseType.divers,
    _           => ExpenseType.salaires,
  };
}

class Expense {
  final String id;
  final String marketId;
  final ExpenseType type;
  final double montant;
  final String? description;
  final String? justificatifUrl;
  final DateTime date;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.marketId,
    required this.type,
    required this.montant,
    this.description,
    this.justificatifUrl,
    required this.date,
    required this.createdAt,
  });

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
    id: m['id'] as String,
    marketId: m['market_id'] as String,
    type: ExpenseTypeExt.fromValue(m['type'] as String? ?? 'divers'),
    montant: (m['montant'] as num).toDouble(),
    description: m['description'] as String?,
    justificatifUrl: m['justificatif_url'] as String?,
    date: DateTime.parse(m['date'] as String),
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  Map<String, dynamic> toInsertMap() => {
    'market_id': marketId,
    'type': type.value,
    'montant': montant.round(),
    if (description != null) 'description': description,
    if (justificatifUrl != null) 'justificatif_url': justificatifUrl,
    'date': date.toIso8601String().substring(0, 10),
  };
}
