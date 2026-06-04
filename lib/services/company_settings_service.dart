import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/company_settings.dart';

class CompanySettingsService {
  static final _db = Supabase.instance.client.from('company_settings');
  static final _storage = Supabase.instance.client.storage;

  static String get _uid => Supabase.instance.client.auth.currentUser!.id;

  /// Retourne les settings du user connecté, ou null si non configuré.
  static Future<CompanySettings?> getMySettings() async {
    final data = await _db
        .select()
        .eq('user_id', _uid)
        .maybeSingle();
    if (data == null) return null;
    return CompanySettings.fromMap(data);
  }

  /// Crée ou met à jour les settings du user connecté.
  static Future<CompanySettings> save(CompanySettings settings) async {
    final map = settings.toMap();
    final existing = await getMySettings();

    if (existing == null) {
      final data = await _db.insert(map).select().single();
      return CompanySettings.fromMap(data);
    } else {
      final data = await _db
          .update(map)
          .eq('user_id', _uid)
          .select()
          .single();
      return CompanySettings.fromMap(data);
    }
  }

  /// Upload le logo et retourne l'URL publique.
  static Future<String> uploadLogo(Uint8List bytes, String ext) async {
    final path = '$_uid/logos/logo.$ext';
    await _storage.from('pdfs').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
        upsert: true,
      ),
    );
    return _storage.from('pdfs').getPublicUrl(path);
  }

  /// Upload la signature et retourne l'URL publique.
  static Future<String> uploadSignature(Uint8List bytes, String ext) async {
    final path = '$_uid/signatures/signature.$ext';
    await _storage.from('pdfs').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
        upsert: true,
      ),
    );
    return _storage.from('pdfs').getPublicUrl(path);
  }
}
