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
        .eq('created_by', _uid)
        .maybeSingle();
    if (data == null) return null;
    return Market.fromMap(data);
  }

  Future<Market> create(Market market) async {
    // Nom du client en majuscules sans espaces pour la codification
    final clientData = await _supabase
        .from('clients')
        .select('nom')
        .eq('id', market.clientId)
        .single();
    final clientCode = (clientData['nom'] as String)
        .toUpperCase()
        .replaceAll(RegExp(r'[ÀÁÂÃÄÅ]'), 'A')
        .replaceAll(RegExp(r'[ÈÉÊË]'), 'E')
        .replaceAll(RegExp(r'[ÌÍÎÏ]'), 'I')
        .replaceAll(RegExp(r'[ÒÓÔÕÖ]'), 'O')
        .replaceAll(RegExp(r'[ÙÚÛÜ]'), 'U')
        .replaceAll('Ç', 'C')
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // Séquence propre à ce client (combien de marchés il a déjà)
    final seqData = await _supabase
        .from('markets')
        .select('id')
        .eq('client_id', market.clientId)
        .count();
    final seq = seqData.count + 1;

    final numero = '$clientCode-MRK${seq.toString().padLeft(3, '0')}-${DateTime.now().year}';

    final insertData = {
      ...market.toInsertMap(),
      'numero': numero,
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
        .eq('created_by', _uid)
        .select('*, clients(nom)')
        .single();
    return Market.fromMap(data);
  }

  Future<Market> update(String id, Map<String, dynamic> fields) async {
    final data = await _supabase
        .from('markets')
        .update(fields)
        .eq('id', id)
        .eq('created_by', _uid)
        .select('*, clients(nom)')
        .single();
    return Market.fromMap(data);
  }

}
