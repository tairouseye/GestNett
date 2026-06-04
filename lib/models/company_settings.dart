class CompanySettings {
  final String? id;
  final String userId;
  final String companyName;
  final String? slogan;
  final String? description;
  final String? adresse;
  final String? telephone;
  final String? email;
  final String? logoUrl;
  final String? signatureUrl;
  final String devise;

  const CompanySettings({
    this.id,
    required this.userId,
    required this.companyName,
    this.slogan,
    this.description,
    this.adresse,
    this.telephone,
    this.email,
    this.logoUrl,
    this.signatureUrl,
    this.devise = 'FCFA',
  });

  factory CompanySettings.fromMap(Map<String, dynamic> m) => CompanySettings(
        id: m['id'] as String?,
        userId: m['user_id'] as String,
        companyName: m['company_name'] as String? ?? '',
        slogan: m['slogan'] as String?,
        description: m['description'] as String?,
        adresse: m['adresse'] as String?,
        telephone: m['telephone'] as String?,
        email: m['email'] as String?,
        logoUrl: m['logo_url'] as String?,
        signatureUrl: m['signature_url'] as String?,
        devise: m['devise'] as String? ?? 'FCFA',
      );

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'company_name': companyName,
        'slogan': slogan,
        'description': description,
        'adresse': adresse,
        'telephone': telephone,
        'email': email,
        'logo_url': logoUrl,
        'signature_url': signatureUrl,
        'devise': devise,
      };

  CompanySettings copyWith({
    String? companyName,
    String? slogan,
    String? description,
    String? adresse,
    String? telephone,
    String? email,
    String? logoUrl,
    String? signatureUrl,
    String? devise,
  }) =>
      CompanySettings(
        id: id,
        userId: userId,
        companyName: companyName ?? this.companyName,
        slogan: slogan ?? this.slogan,
        description: description ?? this.description,
        adresse: adresse ?? this.adresse,
        telephone: telephone ?? this.telephone,
        email: email ?? this.email,
        logoUrl: logoUrl ?? this.logoUrl,
        signatureUrl: signatureUrl ?? this.signatureUrl,
        devise: devise ?? this.devise,
      );
}
