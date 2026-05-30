class Client {
  final String id;
  final String nom;
  final String? contact;
  final String? telephone;
  final String? email;
  final String? adresse;
  final String? ninea;
  final DateTime createdAt;

  const Client({
    required this.id,
    required this.nom,
    this.contact,
    this.telephone,
    this.email,
    this.adresse,
    this.ninea,
    required this.createdAt,
  });

  factory Client.fromMap(Map<String, dynamic> m) => Client(
    id: m['id'] as String,
    nom: m['nom'] as String,
    contact: m['contact'] as String?,
    telephone: m['telephone'] as String?,
    email: m['email'] as String?,
    adresse: m['adresse'] as String?,
    ninea: m['ninea'] as String?,
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
    'created_at': createdAt.toIso8601String(),
  };

  Client copyWith({
    String? nom,
    String? contact,
    String? telephone,
    String? email,
    String? adresse,
    String? ninea,
  }) => Client(
    id: id,
    nom: nom ?? this.nom,
    contact: contact ?? this.contact,
    telephone: telephone ?? this.telephone,
    email: email ?? this.email,
    adresse: adresse ?? this.adresse,
    ninea: ninea ?? this.ninea,
    createdAt: createdAt,
  );
}
