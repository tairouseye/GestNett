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
}
