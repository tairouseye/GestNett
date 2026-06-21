import 'package:flutter/material.dart';

enum ExpenseType {
  // Personnel & terrain
  salaires,
  charges_sociales,
  epi,
  formation,
  restauration,
  // Exploitation (nettoyage / BTP)
  produits,
  materiel,
  location,
  entretien,
  sous_traitance,
  // Véhicules
  transport,
  carburant,
  // Locaux & charges
  loyer,
  eau_electricite,
  assurances,
  charges_fixes,
  communication,
  // Administratif & financier
  impots,
  frais_bancaires,
  honoraires,
  fournitures,
  divers,
}

extension ExpenseTypeExt on ExpenseType {
  String get value => switch (this) {
    ExpenseType.salaires         => 'salaires',
    ExpenseType.charges_sociales => 'charges_sociales',
    ExpenseType.epi              => 'epi',
    ExpenseType.formation        => 'formation',
    ExpenseType.restauration     => 'restauration',
    ExpenseType.produits         => 'produits',
    ExpenseType.materiel         => 'materiel',
    ExpenseType.location         => 'location',
    ExpenseType.entretien        => 'entretien',
    ExpenseType.sous_traitance   => 'sous_traitance',
    ExpenseType.transport        => 'transport',
    ExpenseType.carburant        => 'carburant',
    ExpenseType.loyer            => 'loyer',
    ExpenseType.eau_electricite  => 'eau_electricite',
    ExpenseType.assurances       => 'assurances',
    ExpenseType.charges_fixes    => 'charges_fixes',
    ExpenseType.communication    => 'communication',
    ExpenseType.impots           => 'impots',
    ExpenseType.frais_bancaires  => 'frais_bancaires',
    ExpenseType.honoraires       => 'honoraires',
    ExpenseType.fournitures      => 'fournitures',
    ExpenseType.divers           => 'divers',
  };

  String get label => switch (this) {
    ExpenseType.salaires         => 'Salaires & charges',
    ExpenseType.charges_sociales => 'Charges sociales',
    ExpenseType.epi              => 'EPI & tenues',
    ExpenseType.formation        => 'Formation',
    ExpenseType.restauration     => 'Restauration',
    ExpenseType.produits         => 'Produits de nettoyage',
    ExpenseType.materiel         => 'Matériel & équipements',
    ExpenseType.location         => 'Location matériel/véhicule',
    ExpenseType.entretien        => 'Entretien & réparations',
    ExpenseType.sous_traitance   => 'Sous-traitance',
    ExpenseType.transport        => 'Transport',
    ExpenseType.carburant        => 'Carburant',
    ExpenseType.loyer            => 'Loyer',
    ExpenseType.eau_electricite  => 'Eau & électricité',
    ExpenseType.assurances       => 'Assurances',
    ExpenseType.charges_fixes    => 'Charges fixes',
    ExpenseType.communication    => 'Communication',
    ExpenseType.impots           => 'Impôts & taxes',
    ExpenseType.frais_bancaires  => 'Frais bancaires',
    ExpenseType.honoraires       => 'Honoraires',
    ExpenseType.fournitures      => 'Fournitures de bureau',
    ExpenseType.divers           => 'Divers',
  };

  IconData get icon => switch (this) {
    ExpenseType.salaires         => Icons.people_outline,
    ExpenseType.charges_sociales => Icons.shield_outlined,
    ExpenseType.epi              => Icons.health_and_safety_outlined,
    ExpenseType.formation        => Icons.school_outlined,
    ExpenseType.restauration     => Icons.restaurant_outlined,
    ExpenseType.produits         => Icons.cleaning_services_outlined,
    ExpenseType.materiel         => Icons.handyman_outlined,
    ExpenseType.location         => Icons.inventory_2_outlined,
    ExpenseType.entretien        => Icons.build_outlined,
    ExpenseType.sous_traitance   => Icons.engineering_outlined,
    ExpenseType.transport        => Icons.local_shipping_outlined,
    ExpenseType.carburant        => Icons.local_gas_station_outlined,
    ExpenseType.loyer            => Icons.apartment_outlined,
    ExpenseType.eau_electricite  => Icons.bolt_outlined,
    ExpenseType.assurances       => Icons.verified_user_outlined,
    ExpenseType.charges_fixes    => Icons.home_work_outlined,
    ExpenseType.communication    => Icons.phone_outlined,
    ExpenseType.impots           => Icons.account_balance_outlined,
    ExpenseType.frais_bancaires  => Icons.account_balance_wallet_outlined,
    ExpenseType.honoraires       => Icons.gavel_outlined,
    ExpenseType.fournitures      => Icons.inventory_outlined,
    ExpenseType.divers           => Icons.more_horiz,
  };

  Color get color => switch (this) {
    ExpenseType.salaires         => const Color(0xFF1B4F8A),
    ExpenseType.charges_sociales => const Color(0xFF283593),
    ExpenseType.epi              => const Color(0xFFD84315),
    ExpenseType.formation        => const Color(0xFF00897B),
    ExpenseType.restauration     => const Color(0xFFF4511E),
    ExpenseType.produits         => const Color(0xFF145221),
    ExpenseType.materiel         => const Color(0xFF6D4C41),
    ExpenseType.location         => const Color(0xFF8D6E63),
    ExpenseType.entretien        => const Color(0xFF546E7A),
    ExpenseType.sous_traitance   => const Color(0xFF6A1B9A),
    ExpenseType.transport        => const Color(0xFF00838F),
    ExpenseType.carburant        => const Color(0xFFE65100),
    ExpenseType.loyer            => const Color(0xFF455A64),
    ExpenseType.eau_electricite  => const Color(0xFFF9A825),
    ExpenseType.assurances       => const Color(0xFF5E35B1),
    ExpenseType.charges_fixes    => const Color(0xFF37474F),
    ExpenseType.communication    => const Color(0xFF00695C),
    ExpenseType.impots           => const Color(0xFFC62828),
    ExpenseType.frais_bancaires  => const Color(0xFF1565C0),
    ExpenseType.honoraires       => const Color(0xFF4E342E),
    ExpenseType.fournitures      => const Color(0xFF7E57C2),
    ExpenseType.divers           => const Color(0xFF757575),
  };

  static ExpenseType fromValue(String v) {
    for (final t in ExpenseType.values) {
      if (t.value == v) return t;
    }
    return ExpenseType.divers;
  }

  ExpenseFamille get famille => switch (this) {
    ExpenseType.salaires ||
    ExpenseType.charges_sociales ||
    ExpenseType.epi ||
    ExpenseType.formation ||
    ExpenseType.restauration => ExpenseFamille.personnel,
    ExpenseType.produits ||
    ExpenseType.materiel ||
    ExpenseType.location ||
    ExpenseType.entretien ||
    ExpenseType.sous_traitance => ExpenseFamille.exploitation,
    ExpenseType.transport ||
    ExpenseType.carburant => ExpenseFamille.vehicules,
    ExpenseType.loyer ||
    ExpenseType.eau_electricite ||
    ExpenseType.assurances ||
    ExpenseType.charges_fixes ||
    ExpenseType.communication => ExpenseFamille.locaux,
    ExpenseType.impots ||
    ExpenseType.frais_bancaires ||
    ExpenseType.honoraires ||
    ExpenseType.fournitures ||
    ExpenseType.divers => ExpenseFamille.administratif,
  };
}

/// Familles de regroupement des rubriques de dépenses.
enum ExpenseFamille { personnel, exploitation, vehicules, locaux, administratif }

extension ExpenseFamilleExt on ExpenseFamille {
  String get label => switch (this) {
    ExpenseFamille.personnel     => 'Personnel & terrain',
    ExpenseFamille.exploitation  => 'Exploitation',
    ExpenseFamille.vehicules     => 'Véhicules',
    ExpenseFamille.locaux        => 'Locaux & charges',
    ExpenseFamille.administratif => 'Administratif & financier',
  };
  IconData get icon => switch (this) {
    ExpenseFamille.personnel     => Icons.groups_outlined,
    ExpenseFamille.exploitation  => Icons.cleaning_services_outlined,
    ExpenseFamille.vehicules     => Icons.local_shipping_outlined,
    ExpenseFamille.locaux        => Icons.home_work_outlined,
    ExpenseFamille.administratif => Icons.account_balance_outlined,
  };
  Color get color => switch (this) {
    ExpenseFamille.personnel     => const Color(0xFF1B4F8A),
    ExpenseFamille.exploitation  => const Color(0xFF145221),
    ExpenseFamille.vehicules     => const Color(0xFF00838F),
    ExpenseFamille.locaux        => const Color(0xFF37474F),
    ExpenseFamille.administratif => const Color(0xFF6A1B9A),
  };

  List<ExpenseType> get types =>
      ExpenseType.values.where((t) => t.famille == this).toList();
}

class Expense {
  final String id;
  final String? marketId; // null = frais général (non rattaché à un marché)
  final String? marketNumero;
  final ExpenseType type;
  final double montant;
  final String? description;
  final String? justificatifUrl;
  final DateTime date;
  final DateTime createdAt;

  const Expense({
    required this.id,
    this.marketId,
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
    marketId: m['market_id'] as String?,
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
    if (marketId != null) 'market_id': marketId,
    'type': type.value,
    'montant': montant.round(),
    if (description != null && description!.isNotEmpty)
      'description': description,
    'date': date.toIso8601String().substring(0, 10),
  };
}
