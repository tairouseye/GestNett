import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  static final _storage = Supabase.instance.client.storage;
  static String get _uid => Supabase.instance.client.auth.currentUser!.id;

  /// Upload un PDF dans le bucket 'pdfs' sous le dossier propre à l'utilisateur.
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

    return _storage.from(bucket).getPublicUrl(path);
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
}
