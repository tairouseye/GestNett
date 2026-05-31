import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  static final _storage = Supabase.instance.client.storage;

  /// Upload un PDF dans le bucket 'pdfs' et retourne l'URL publique
  static Future<String> uploadPdf(Uint8List bytes, String filename) async {
    const bucket = 'pdfs';
    final path = 'factures/$filename';

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
