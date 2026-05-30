enum PaymentType { totalite, acompte, partiel }

extension PaymentTypeExt on PaymentType {
  String get value => switch (this) {
    PaymentType.totalite => 'totalite',
    PaymentType.acompte  => 'acompte',
    PaymentType.partiel  => 'partiel',
  };

  String get label => switch (this) {
    PaymentType.totalite => 'Totalité',
    PaymentType.acompte  => 'Acompte',
    PaymentType.partiel  => 'Partiel',
  };

  static PaymentType fromValue(String v) => switch (v) {
    'acompte' => PaymentType.acompte,
    'partiel' => PaymentType.partiel,
    _         => PaymentType.totalite,
  };
}

class Payment {
  final String id;
  final String invoiceId;
  final double montant;
  final DateTime date;
  final PaymentType type;
  final String? notes;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.invoiceId,
    required this.montant,
    required this.date,
    required this.type,
    this.notes,
    required this.createdAt,
  });

  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
    id: m['id'] as String,
    invoiceId: m['invoice_id'] as String,
    montant: (m['montant'] as num).toDouble(),
    date: DateTime.parse(m['date'] as String),
    type: PaymentTypeExt.fromValue(m['type'] as String? ?? 'partiel'),
    notes: m['notes'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  Map<String, dynamic> toInsertMap() => {
    'invoice_id': invoiceId,
    'montant': montant.round(),
    'date': date.toIso8601String().substring(0, 10),
    'type': type.value,
    if (notes != null) 'notes': notes,
  };
}
