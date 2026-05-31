import 'package:flutter/material.dart';

enum ExpenseType {
  salaires,
  produits,
  materiel,
  transport,
  carburant,
  sous_traitance,
  charges_fixes,
  communication,
  divers,
}

extension ExpenseTypeExt on ExpenseType {
  String get value => switch (this) {
    ExpenseType.salaires       => 'salaires',
    ExpenseType.produits       => 'produits',
    ExpenseType.materiel       => 'materiel',
    ExpenseType.transport      => 'transport',
    ExpenseType.carburant      => 'carburant',
    ExpenseType.sous_traitance => 'sous_traitance',
    ExpenseType.charges_fixes  => 'charges_fixes',
    ExpenseType.communication  => 'communication',
    ExpenseType.divers         => 'divers',
  };

  String get label => switch (this) {
    ExpenseType.salaires       => 'Salaires & charges',
    ExpenseType.produits       => 'Produits de nettoyage',
    ExpenseType.materiel       => 'Matériel & équipements',
    ExpenseType.transport      => 'Transport',
    ExpenseType.carburant      => 'Carburant',
    ExpenseType.sous_traitance => 'Sous-traitance',
    ExpenseType.charges_fixes  => 'Charges fixes',
    ExpenseType.communication  => 'Communication',
    ExpenseType.divers         => 'Divers',
  };

  IconData get icon => switch (this) {
    ExpenseType.salaires       => Icons.people_outline,
    ExpenseType.produits       => Icons.cleaning_services_outlined,
    ExpenseType.materiel       => Icons.handyman_outlined,
    ExpenseType.transport      => Icons.local_shipping_outlined,
    ExpenseType.carburant      => Icons.local_gas_station_outlined,
    ExpenseType.sous_traitance => Icons.engineering_outlined,
    ExpenseType.charges_fixes  => Icons.home_work_outlined,
    ExpenseType.communication  => Icons.phone_outlined,
    ExpenseType.divers         => Icons.more_horiz,
  };

  Color get color => switch (this) {
    ExpenseType.salaires       => const Color(0xFF1B4F8A),
    ExpenseType.produits       => const Color(0xFF145221),
    ExpenseType.materiel       => const Color(0xFF6D4C41),
    ExpenseType.transport      => const Color(0xFF00838F),
    ExpenseType.carburant      => const Color(0xFFE65100),
    ExpenseType.sous_traitance => const Color(0xFF6A1B9A),
    ExpenseType.charges_fixes  => const Color(0xFF37474F),
    ExpenseType.communication  => const Color(0xFF00695C),
    ExpenseType.divers         => const Color(0xFF757575),
  };

  static ExpenseType fromValue(String v) => switch (v) {
    'produits'       => ExpenseType.produits,
    'materiel'       => ExpenseType.materiel,
    'transport'      => ExpenseType.transport,
    'carburant'      => ExpenseType.carburant,
    'sous_traitance' => ExpenseType.sous_traitance,
    'charges_fixes'  => ExpenseType.charges_fixes,
    'communication'  => ExpenseType.communication,
    'divers'         => ExpenseType.divers,
    _                => ExpenseType.salaires,
  };
}

class Expense {
  final String id;
  final String marketId;
  final String? marketNumero;
  final ExpenseType type;
  final double montant;
  final String? description;
  final String? justificatifUrl;
  final DateTime date;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.marketId,
    this.marketNumero,
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
    marketNumero: m['markets'] != null
        ? (m['markets'] as Map)['numero'] as String?
        : null,
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
    if (description != null && description!.isNotEmpty)
      'description': description,
    'date': date.toIso8601String().substring(0, 10),
  };
}
