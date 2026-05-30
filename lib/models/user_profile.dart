class UserProfile {
  final String id;
  final String email;
  final String nom;
  final String role; // 'admin' | 'gestionnaire'
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.nom,
    required this.role,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    id: m['id'] as String,
    email: m['email'] as String? ?? '',
    nom: m['nom'] as String? ?? '',
    role: m['role'] as String? ?? 'gestionnaire',
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'nom': nom,
    'role': role,
    'created_at': createdAt.toIso8601String(),
  };
}
