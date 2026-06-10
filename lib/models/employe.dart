enum EmployeStatut { actif, inactif }

extension EmployeStatutExt on EmployeStatut {
  String get value => switch (this) {
    EmployeStatut.actif   => 'actif',
    EmployeStatut.inactif => 'inactif',
  };
  String get label => switch (this) {
    EmployeStatut.actif   => 'Actif',
    EmployeStatut.inactif => 'Inactif',
  };
  static EmployeStatut fromValue(String v) =>
      v == 'inactif' ? EmployeStatut.inactif : EmployeStatut.actif;
}

class Employe {
  final String id;
  final String nom;
  final String? prenom;
  final String? poste;
  final String? telephone;
  final double salaireMensuel;   // = salaire brut
  final double partPatronale;
  final String fraisGestionType; // 'montant' | 'pct'
  final double fraisGestionMontant;
  final double fraisGestionPct;
  final String? matricule;
  final DateTime? dateEmbauche;
  final EmployeStatut statut;
  final String? notes;
  final DateTime createdAt;

  const Employe({
    required this.id,
    required this.nom,
    this.prenom,
    this.poste,
    this.telephone,
    this.salaireMensuel = 0,
    this.partPatronale = 0,
    this.fraisGestionType = 'montant',
    this.fraisGestionMontant = 0,
    this.fraisGestionPct = 0,
    this.matricule,
    this.dateEmbauche,
    this.statut = EmployeStatut.actif,
    this.notes,
    required this.createdAt,
  });

  String get nomComplet => prenom != null ? '$prenom $nom' : nom;

  double get fraisGestion => fraisGestionType == 'pct'
      ? salaireMensuel * fraisGestionPct / 100
      : fraisGestionMontant;

  double get coutTotal => salaireMensuel + partPatronale + fraisGestion;

  factory Employe.fromMap(Map<String, dynamic> m) => Employe(
        id:                   m['id'] as String,
        nom:                  m['nom'] as String,
        prenom:               m['prenom'] as String?,
        poste:                m['poste'] as String?,
        telephone:            m['telephone'] as String?,
        salaireMensuel:       (m['salaire_mensuel'] as num?)?.toDouble() ?? 0,
        partPatronale:        (m['part_patronale'] as num?)?.toDouble() ?? 0,
        fraisGestionType:     m['frais_gestion_type'] as String? ?? 'montant',
        fraisGestionMontant:  (m['frais_gestion_montant'] as num?)?.toDouble() ?? 0,
        fraisGestionPct:      (m['frais_gestion_pct'] as num?)?.toDouble() ?? 0,
        matricule:            m['matricule'] as String?,
        dateEmbauche:         m['date_embauche'] != null
            ? DateTime.parse(m['date_embauche'] as String)
            : null,
        statut:    EmployeStatutExt.fromValue(m['statut'] as String? ?? 'actif'),
        notes:     m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'nom':                   nom,
        if (prenom != null)      'prenom':               prenom,
        if (poste != null)       'poste':                poste,
        if (telephone != null)   'telephone':            telephone,
        'salaire_mensuel':       salaireMensuel.round(),
        'part_patronale':        partPatronale.round(),
        'frais_gestion_type':    fraisGestionType,
        'frais_gestion_montant': fraisGestionMontant.round(),
        'frais_gestion_pct':     fraisGestionPct,
        if (matricule != null)   'matricule':            matricule,
        if (dateEmbauche != null)'date_embauche':        dateEmbauche!.toIso8601String().substring(0, 10),
        'statut':                statut.value,
        if (notes != null)       'notes':                notes,
      };
}

class Affectation {
  final String id;
  final String employeId;
  final String marketId;
  final String? employeNom;
  final String? marketNumero;
  final double? salaireMensuel;
  final double? partPatronale;
  final String? fraisGestionType;
  final double? fraisGestionMontant;
  final double? fraisGestionPct;
  final DateTime dateDebut;
  final DateTime? dateFin;

  const Affectation({
    required this.id,
    required this.employeId,
    required this.marketId,
    this.employeNom,
    this.marketNumero,
    this.salaireMensuel,
    this.partPatronale,
    this.fraisGestionType,
    this.fraisGestionMontant,
    this.fraisGestionPct,
    required this.dateDebut,
    this.dateFin,
  });

  bool get enCours => dateFin == null;

  double get fraisGestion {
    final brut = salaireMensuel ?? 0;
    final type = fraisGestionType ?? 'montant';
    if (type == 'pct') return brut * (fraisGestionPct ?? 0) / 100;
    return fraisGestionMontant ?? 0;
  }

  double get coutTotal =>
      (salaireMensuel ?? 0) + (partPatronale ?? 0) + fraisGestion;

  factory Affectation.fromMap(Map<String, dynamic> m) {
    final e = m['employes'] as Map<String, dynamic>?;
    return Affectation(
      id:         m['id'] as String,
      employeId:  m['employe_id'] as String,
      marketId:   m['market_id'] as String,
      employeNom: e != null ? _buildNom(e) : null,
      salaireMensuel:      e != null ? (e['salaire_mensuel'] as num?)?.toDouble() : null,
      partPatronale:       e != null ? (e['part_patronale'] as num?)?.toDouble() : null,
      fraisGestionType:    e != null ? e['frais_gestion_type'] as String? : null,
      fraisGestionMontant: e != null ? (e['frais_gestion_montant'] as num?)?.toDouble() : null,
      fraisGestionPct:     e != null ? (e['frais_gestion_pct'] as num?)?.toDouble() : null,
      marketNumero: m['markets'] != null
          ? (m['markets'] as Map<String, dynamic>)['numero'] as String?
          : null,
      dateDebut: DateTime.parse(m['date_debut'] as String),
      dateFin:   m['date_fin'] != null
          ? DateTime.parse(m['date_fin'] as String)
          : null,
    );
  }

  static String _buildNom(Map<String, dynamic> e) {
    final prenom = e['prenom'] as String?;
    final nom    = e['nom'] as String? ?? '';
    return prenom != null ? '$prenom $nom' : nom;
  }
}
