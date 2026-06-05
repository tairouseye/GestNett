import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/market.dart';

class MarketService {
  final _supabase = Supabase.instance.client;
  String get _uid => _supabase.auth.currentUser!.id;

  Future<List<Market>> getAll() async {
    final data = await _supabase
        .from('markets')
        .select('*, clients(nom)')
        .eq('created_by', _uid)
        .order('created_at', ascending: false);
    return (data as List).map((m) => Market.fromMap(m)).toList();
  }

  Future<List<Market>> getActive() async {
    final data = await _supabase
        .from('markets')
        .select('*, clients(nom)')
        .eq('created_by', _uid)
        .eq('statut', 'en_cours')
        .order('date_debut', ascending: false);
    return (data as List).map((m) => Market.fromMap(m)).toList();
  }

  Future<Market?> getById(String id) async {
    final data = await _supabase
        .from('markets')
        .select('*, clients(nom)')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Market.fromMap(data);
  }

  Future<Market> create(Market market) async {
    final seq = await _nextSequence();
    final insertData = {
      ...market.toInsertMap(),
      'numero': 'MRK-${DateTime.now().year}-${seq.toString().padLeft(3, '0')}',
      'created_at': DateTime.now().toIso8601String(),
      'created_by': _uid,
    };
    final data = await _supabase
        .from('markets')
        .insert(insertData)
        .select('*, clients(nom)')
        .single();
    return Market.fromMap(data);
  }

  Future<Market> updateStatut(String id, MarketStatut statut) async {
    final data = await _supabase
        .from('markets')
        .update({'statut': statut.value})
        .eq('id', id)
        .select('*, clients(nom)')
        .single();
    return Market.fromMap(data);
  }

  Future<Market> update(String id, Map<String, dynamic> fields) async {
    final data = await _supabase
        .from('markets')
        .update(fields)
        .eq('id', id)
        .select('*, clients(nom)')
        .single();
    return Market.fromMap(data);
  }

  Future<int> _nextSequence() async {
    final data = await _supabase
        .from('markets')
        .select('id')
        .count();
    return data.count + 1;
  }
}
