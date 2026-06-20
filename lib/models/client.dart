class Client {
  final String id;
  final String nom;
  final String? contact;
  final String? telephone;
  final String? email;
  final String? adresse;
  final String? ninea;
  final String? type;   // 'particulier' | 'entreprise'
  final String? notes;
  final DateTime createdAt;

  const Client({
    required this.id,
    required this.nom,
    this.contact,
    this.telephone,
    this.email,
    this.adresse,
    this.ninea,
    this.type,
    this.notes,
    required this.createdAt,
  });

  String get typeLabel => switch (type) {
        'particulier' => 'Particulier',
        'entreprise'  => 'Entreprise',
        _             => '—',
      };
  bool get isEntreprise => type == 'entreprise';

  factory Client.fromMap(Map<String, dynamic> m) => Client(
        id: m['id'] as String,
        nom: m['nom'] as String,
        contact: m['contact'] as String?,
        telephone: m['telephone'] as String?,
        email: m['email'] as String?,
        adresse: m['adresse'] as String?,
        ninea: m['ninea'] as String?,
        type: m['type'] as String?,
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        if (contact != null) 'contact': contact,
        if (telephone != null) 'telephone': telephone,
        if (email != null) 'email': email,
        if (adresse != null) 'adresse': adresse,
        if (ninea != null) 'ninea': ninea,
        if (type != null) 'type': type,
        if (notes != null) 'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  Client copyWith({
    String? nom,
    String? contact,
    String? telephone,
    String? email,
    String? adresse,
    String? ninea,
    String? type,
    String? notes,
  }) =>
      Client(
        id: id,
        nom: nom ?? this.nom,
        contact: contact ?? this.contact,
        telephone: telephone ?? this.telephone,
        email: email ?? this.email,
        adresse: adresse ?? this.adresse,
        ninea: ninea ?? this.ninea,
        type: type ?? this.type,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}
