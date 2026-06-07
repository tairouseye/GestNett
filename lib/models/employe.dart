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
  final double salaireMensuel;
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
    this.dateEmbauche,
    this.statut = EmployeStatut.actif,
    this.notes,
    required this.createdAt,
  });

  String get nomComplet => prenom != null ? '$prenom $nom' : nom;

  factory Employe.fromMap(Map<String, dynamic> m) => Employe(
        id:             m['id'] as String,
        nom:            m['nom'] as String,
        prenom:         m['prenom'] as String?,
        poste:          m['poste'] as String?,
        telephone:      m['telephone'] as String?,
        salaireMensuel: (m['salaire_mensuel'] as num?)?.toDouble() ?? 0,
        dateEmbauche:   m['date_embauche'] != null
            ? DateTime.parse(m['date_embauche'] as String)
            : null,
        statut:    EmployeStatutExt.fromValue(m['statut'] as String? ?? 'actif'),
        notes:     m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'nom':             nom,
        if (prenom != null)       'prenom':         prenom,
        if (poste != null)        'poste':          poste,
        if (telephone != null)    'telephone':      telephone,
        'salaire_mensuel': salaireMensuel.round(),
        if (dateEmbauche != null) 'date_embauche':  dateEmbauche!.toIso8601String().substring(0, 10),
        'statut':          statut.value,
        if (notes != null)        'notes':          notes,
      };
}

class Affectation {
  final String id;
  final String employeId;
  final String marketId;
  final String? employeNom;
  final String? marketNumero;
  final double? salaireMensuel;
  final DateTime dateDebut;
  final DateTime? dateFin;

  const Affectation({
    required this.id,
    required this.employeId,
    required this.marketId,
    this.employeNom,
    this.marketNumero,
    this.salaireMensuel,
    required this.dateDebut,
    this.dateFin,
  });

  bool get enCours => dateFin == null;

  factory Affectation.fromMap(Map<String, dynamic> m) => Affectation(
        id:         m['id'] as String,
        employeId:  m['employe_id'] as String,
        marketId:   m['market_id'] as String,
        employeNom: m['employes'] != null
            ? _buildNom(m['employes'] as Map<String, dynamic>)
            : null,
        salaireMensuel: m['employes'] != null
            ? ((m['employes'] as Map<String, dynamic>)['salaire_mensuel'] as num?)?.toDouble()
            : null,
        marketNumero: m['markets'] != null
            ? (m['markets'] as Map<String, dynamic>)['numero'] as String?
            : null,
        dateDebut: DateTime.parse(m['date_debut'] as String),
        dateFin:   m['date_fin'] != null
            ? DateTime.parse(m['date_fin'] as String)
            : null,
      );

  static String _buildNom(Map<String, dynamic> e) {
    final prenom = e['prenom'] as String?;
    final nom    = e['nom'] as String? ?? '';
    return prenom != null ? '$prenom $nom' : nom;
  }
}
