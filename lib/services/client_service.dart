import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client.dart';

class ClientService {
  final _db = Supabase.instance.client.from('clients');
  String get _uid => Supabase.instance.client.auth.currentUser!.id;

  Future<List<Client>> getAll() async {
    final data = await _db
        .select()
        .eq('created_by', _uid)
        .order('nom', ascending: true);
    return (data as List).map((m) => Client.fromMap(m)).toList();
  }

  Future<Client?> getById(String id) async {
    final data = await _db.select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return Client.fromMap(data);
  }

  Future<Client> create(Map<String, dynamic> fields) async {
    final data = await _db
        .insert({
          ...fields,
          'created_at': DateTime.now().toIso8601String(),
          'created_by': _uid,
        })
        .select()
        .single();
    return Client.fromMap(data);
  }

  Future<Client> update(String id, Map<String, dynamic> fields) async {
    final data = await _db
        .update(fields)
        .eq('id', id)
        .select()
        .single();
    return Client.fromMap(data);
  }

  Future<void> delete(String id) => _db.delete().eq('id', id);

  // Recherche par nom
  Future<List<Client>> search(String query) async {
    final data = await _db
        .select()
        .eq('created_by', _uid)
        .ilike('nom', '%$query%')
        .order('nom', ascending: true);
    return (data as List).map((m) => Client.fromMap(m)).toList();
  }
}
