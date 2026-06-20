class EmployeDocument {
  final String id;
  final String employeId;
  final String nom;
  final String? type; // cni | contrat | certificat_medical | autre
  final String url;
  final DateTime createdAt;

  const EmployeDocument({
    required this.id,
    required this.employeId,
    required this.nom,
    this.type,
    required this.url,
    required this.createdAt,
  });

  static const types = <String, String>{
    'cni': 'CNI / Pièce d\'identité',
    'contrat': 'Contrat',
    'certificat_medical': 'Certificat médical',
    'autre': 'Autre',
  };

  String get typeLabel => types[type] ?? 'Document';

  factory EmployeDocument.fromMap(Map<String, dynamic> m) => EmployeDocument(
        id:        m['id'] as String,
        employeId: m['employe_id'] as String,
        nom:       m['nom'] as String,
        type:      m['type'] as String?,
        url:       m['url'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'employe_id': employeId,
        'nom': nom,
        if (type != null) 'type': type,
        'url': url,
      };
}
