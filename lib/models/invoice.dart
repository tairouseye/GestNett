enum InvoiceStatut { brouillon, emise, payeePartiel, payee, annulee }

extension InvoiceStatutExt on InvoiceStatut {
  String get value => switch (this) {
    InvoiceStatut.brouillon   => 'brouillon',
    InvoiceStatut.emise       => 'emise',
    InvoiceStatut.payeePartiel => 'payee_partiel',
    InvoiceStatut.payee       => 'payee',
    InvoiceStatut.annulee     => 'annulee',
  };

  String get label => switch (this) {
    InvoiceStatut.brouillon   => 'Brouillon',
    InvoiceStatut.emise       => 'Émise',
    InvoiceStatut.payeePartiel => 'Acompte',
    InvoiceStatut.payee       => 'Soldée',
    InvoiceStatut.annulee     => 'Annulée',
  };

  static InvoiceStatut fromValue(String v) => switch (v) {
    'emise'        => InvoiceStatut.emise,
    'payee_partiel' => InvoiceStatut.payeePartiel,
    'payee'        => InvoiceStatut.payee,
    'annulee'      => InvoiceStatut.annulee,
    _              => InvoiceStatut.brouillon,
  };
}

class Invoice {
  final String id;
  final String numero;
  final String? marketId;
  final String? marketNumero;
  final String clientId;
  final String? clientNom;
  final String? clientTelephone;
  final DateTime date;
  final double montantHt;
  final double tvaPct;
  final double totalTtc;
  final InvoiceStatut statut;
  final String typeFacture; // 'proforma' | 'definitive'
  final String? pdfUrl;
  final DateTime? dateEcheance;
  final DateTime createdAt;

  const Invoice({
    required this.id,
    required this.numero,
    this.marketId,
    this.marketNumero,
    required this.clientId,
    this.clientNom,
    this.clientTelephone,
    required this.date,
    required this.montantHt,
    this.tvaPct = 18.0,
    required this.totalTtc,
    required this.statut,
    this.typeFacture = 'definitive',
    this.pdfUrl,
    this.dateEcheance,
    required this.createdAt,
  });

  double get montantTva  => montantHt * tvaPct / 100;
  bool   get isProforma  => typeFacture == 'proforma';

  /// Échéance effective (date saisie, sinon date + 30 jours par défaut).
  DateTime get echeance => dateEcheance ?? date.add(const Duration(days: 30));

  factory Invoice.fromMap(Map<String, dynamic> m) => Invoice(
    id: m['id'] as String,
    numero: m['numero'] as String,
    marketId: m['market_id'] as String?,
    marketNumero: m['markets'] != null
        ? (m['markets'] as Map<String, dynamic>)['numero'] as String?
        : null,
    clientId: m['client_id'] as String,
    clientNom: m['clients'] != null
        ? (m['clients'] as Map<String, dynamic>)['nom'] as String?
        : null,
    clientTelephone: m['clients'] != null
        ? (m['clients'] as Map<String, dynamic>)['telephone'] as String?
        : null,
    date: DateTime.parse(m['date'] as String),
    montantHt: (m['montant_ht'] as num?)?.toDouble() ?? 0,
    tvaPct: (m['tva_pct'] as num?)?.toDouble() ?? 18,
    totalTtc: (m['total_ttc'] as num?)?.toDouble() ?? 0,
    statut:      InvoiceStatutExt.fromValue(m['statut'] as String? ?? 'brouillon'),
    typeFacture: m['type_facture'] as String? ?? 'definitive',
    pdfUrl:      m['pdf_url'] as String?,
    dateEcheance: m['date_echeance'] != null
        ? DateTime.parse(m['date_echeance'] as String)
        : null,
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  Map<String, dynamic> toInsertMap() => {
    'numero': numero,
    if (marketId != null) 'market_id': marketId,
    'client_id': clientId,
    'date': date.toIso8601String().substring(0, 10),
    'montant_ht': montantHt.round(),
    'tva_pct': tvaPct,
    'total_ttc': totalTtc.round(),
    'statut':       statut.value,
    'type_facture': typeFacture,
    if (pdfUrl != null) 'pdf_url': pdfUrl,
    if (dateEcheance != null) 'date_echeance': dateEcheance!.toIso8601String().substring(0, 10),
  };
}
