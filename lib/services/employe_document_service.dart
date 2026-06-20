import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employe_document.dart';

class EmployeDocumentService {
  final _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  Future<List<EmployeDocument>> getByEmploye(String employeId) async {
    final data = await _db
        .from('employe_documents')
        .select()
        .eq('employe_id', employeId)
        .eq('created_by', _uid)
        .order('created_at', ascending: false);
    return (data as List).map((m) => EmployeDocument.fromMap(m)).toList();
  }

  Future<EmployeDocument> add(EmployeDocument doc) async {
    final data = await _db
        .from('employe_documents')
        .insert({
          ...doc.toInsertMap(),
          'created_by': _uid,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return EmployeDocument.fromMap(data);
  }

  Future<void> delete(String id) async {
    await _db.from('employe_documents').delete().eq('id', id).eq('created_by', _uid);
  }
}
