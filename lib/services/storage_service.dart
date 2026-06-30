import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  static final _storage = Supabase.instance.client.storage;
  static String get _uid => Supabase.instance.client.auth.currentUser!.id;

  /// Upload un PDF dans le bucket privé 'pdfs' sous le dossier propre à
  /// l'utilisateur. Retourne le **chemin** (à signer à la lecture), pas une URL.
  static Future<String> uploadPdf(Uint8List bytes, String filename) async {
    const bucket = 'pdfs';
    final path = '$_uid/factures/$filename';

    await _storage.from(bucket).uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'application/pdf',
        upsert: true,
      ),
    );

    return path;
  }

  /// Upload la photo d'un employé (bucket public 'logos', sous-dossier employes/).
  static Future<String> uploadEmployePhoto(Uint8List bytes, String ext) async {
    final clean = ext.toLowerCase() == 'jpg' ? 'jpeg' : ext.toLowerCase();
    final path = '$_uid/employes/${DateTime.now().millisecondsSinceEpoch}.$clean';
    await _storage.from('logos').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: clean == 'png' ? 'image/png' : 'image/jpeg',
        upsert: true,
      ),
    );
    return _storage.from('logos').getPublicUrl(path);
  }

  /// Upload un justificatif de dépense (bucket privé 'justificatifs').
  /// Retourne le **chemin** (à signer à la lecture), pas une URL.
  static Future<String> uploadJustificatif(Uint8List bytes, String ext) async {
    final clean = ext.toLowerCase() == 'jpg' ? 'jpeg' : ext.toLowerCase();
    final path = '$_uid/${DateTime.now().millisecondsSinceEpoch}.$clean';
    final ct = switch (clean) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      _     => 'image/jpeg',
    };
    await _storage.from('justificatifs').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: ct, upsert: true),
    );
    return path;
  }

  /// Upload un document d'employé (bucket privé 'pdfs', sous-dossier employes/).
  /// Retourne le **chemin** (à signer à la lecture), pas une URL.
  static Future<String> uploadEmployeDoc(
      Uint8List bytes, String employeId, String ext) async {
    final clean = ext.toLowerCase();
    final path = '$_uid/employes/$employeId/docs/${DateTime.now().millisecondsSinceEpoch}.$clean';
    final ct = switch (clean) {
      'pdf'         => 'application/pdf',
      'png'         => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _             => 'application/octet-stream',
    };
    await _storage.from('pdfs').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: ct, upsert: true),
    );
    return path;
  }

  // ───────────────────────── Lecture (buckets privés) ─────────────────────────

  /// Génère une URL signée temporaire pour un objet d'un bucket privé.
  /// [stored] peut être un chemin nu (nouveaux enregistrements) ou une ancienne
  /// URL publique complète (enregistrements antérieurs au passage en privé) :
  /// dans les deux cas, le chemin réel est extrait avant signature.
  static Future<String> signedUrl(String bucket, String stored,
      {int expiresIn = 3600}) async {
    final path = _extractPath(bucket, stored);
    return _storage.from(bucket).createSignedUrl(path, expiresIn);
  }

  /// URL signée pour un objet du bucket privé 'pdfs' (factures, documents RH).
  static Future<String> signedPdfUrl(String stored) => signedUrl('pdfs', stored);

  /// URL signée pour un objet du bucket privé 'justificatifs'.
  static Future<String> signedJustificatifUrl(String stored) =>
      signedUrl('justificatifs', stored);

  /// Extrait le chemin de stockage d'une valeur enregistrée, qu'elle soit déjà
  /// un chemin nu (`uid/...`) ou une URL Supabase complète
  /// (`.../object/public/<bucket>/uid/...` ou `.../object/sign/...`).
  static String _extractPath(String bucket, String stored) {
    if (!stored.startsWith('http')) return stored;
    const marker = '/object/';
    final i = stored.indexOf(marker);
    if (i == -1) return stored;
    var rest = stored.substring(i + marker.length); // ex: public/pdfs/uid/...
    final slash = rest.indexOf('/'); // retire le mode d'accès (public|sign|...)
    if (slash != -1) rest = rest.substring(slash + 1); // pdfs/uid/...
    final prefix = '$bucket/';
    if (rest.startsWith(prefix)) rest = rest.substring(prefix.length); // uid/...
    final q = rest.indexOf('?'); // retire un éventuel token de requête
    if (q != -1) rest = rest.substring(0, q);
    return rest;
  }
}
