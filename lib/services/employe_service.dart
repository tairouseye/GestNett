import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employe.dart';

class EmployeService {
  final _db      = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  // ── Employés ──────────────────────────────────────────────────────────────

  Future<List<Employe>> getAll() async {
    final data = await _db
        .from('employes')
        .select()
        .eq('created_by', _uid)
        .order('nom');
    return (data as List).map((m) => Employe.fromMap(m)).toList();
  }

  Future<List<Employe>> getActifs() async {
    final data = await _db
        .from('employes')
        .select()
        .eq('created_by', _uid)
        .eq('statut', 'actif')
        .order('nom');
    return (data as List).map((m) => Employe.fromMap(m)).toList();
  }

  Future<Employe?> getById(String id) async {
    final data = await _db
        .from('employes')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Employe.fromMap(data);
  }

  Future<Employe> create(Employe employe) async {
    final data = await _db
        .from('employes')
        .insert({
          ...employe.toInsertMap(),
          'created_by': _uid,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return Employe.fromMap(data);
  }

  Future<Employe> update(String id, Employe employe) async {
    final data = await _db
        .from('employes')
        .update(employe.toInsertMap())
        .eq('id', id)
        .select()
        .single();
    return Employe.fromMap(data);
  }

  Future<void> delete(String id) async {
    await _db.from('employes').delete().eq('id', id);
  }

  // ── Affectations ──────────────────────────────────────────────────────────

  /// Affectations d'un marché (avec nom de l'employé)
  Future<List<Affectation>> getByMarket(String marketId) async {
    final data = await _db
        .from('affectations')
        .select('*, employes(nom, prenom, salaire_mensuel)')
        .eq('market_id', marketId)
        .eq('created_by', _uid)
        .order('date_debut');
    return (data as List).map((m) => Affectation.fromMap(m)).toList();
  }

  /// Affectations d'un employé (avec numéro du marché)
  Future<List<Affectation>> getByEmploye(String employeId) async {
    final data = await _db
        .from('affectations')
        .select('*, markets(numero)')
        .eq('employe_id', employeId)
        .eq('created_by', _uid)
        .order('date_debut', ascending: false);
    return (data as List).map((m) => Affectation.fromMap(m)).toList();
  }

  Future<Affectation> affecter({
    required String employeId,
    required String marketId,
    required DateTime dateDebut,
  }) async {
    final data = await _db
        .from('affectations')
        .insert({
          'employe_id': employeId,
          'market_id':  marketId,
          'date_debut': dateDebut.toIso8601String().substring(0, 10),
          'created_by': _uid,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('*, employes(nom, prenom), markets(numero)')
        .single();
    return Affectation.fromMap(data);
  }

  Future<void> terminerAffectation(String affectationId) async {
    await _db
        .from('affectations')
        .update({'date_fin': DateTime.now().toIso8601String().substring(0, 10)})
        .eq('id', affectationId);
  }

  Future<void> supprimerAffectation(String affectationId) async {
    await _db.from('affectations').delete().eq('id', affectationId);
  }

  /// Coût salarial mensuel total d'un marché (employés actifs)
  Future<double> coutSalarialMarket(String marketId) async {
    final data = await _db
        .from('affectations')
        .select('employes(salaire_mensuel)')
        .eq('market_id', marketId)
        .eq('created_by', _uid)
        .isFilter('date_fin', null);
    return (data as List).fold<double>(0, (sum, row) {
      final emp = row['employes'] as Map<String, dynamic>?;
      return sum + ((emp?['salaire_mensuel'] as num?)?.toDouble() ?? 0);
    });
  }
}
