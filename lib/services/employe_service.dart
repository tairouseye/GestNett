import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employe.dart';
import 'company_settings_service.dart';

class EmployeService {
  final _db      = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  // ── Employés ──────────────────────────────────────────────────────────────

  static const _selectWithSup = '*, superviseur:superviseur_id(nom, prenom)';

  Future<List<Employe>> getAll() async {
    final data = await _db
        .from('employes')
        .select(_selectWithSup)
        .eq('created_by', _uid)
        .order('nom');
    return (data as List).map((m) => Employe.fromMap(m)).toList();
  }

  Future<List<Employe>> getActifs() async {
    final data = await _db
        .from('employes')
        .select(_selectWithSup)
        .eq('created_by', _uid)
        .eq('statut', 'actif')
        .order('nom');
    return (data as List).map((m) => Employe.fromMap(m)).toList();
  }

  /// Employés de catégorie supervision (pour choisir le N+1).
  Future<List<Employe>> getSuperviseurs() async {
    final data = await _db
        .from('employes')
        .select()
        .eq('created_by', _uid)
        .eq('categorie', 'supervision')
        .eq('statut', 'actif')
        .order('nom');
    return (data as List).map((m) => Employe.fromMap(m)).toList();
  }

  Future<Employe?> getById(String id) async {
    final data = await _db
        .from('employes')
        .select(_selectWithSup)
        .eq('id', id)
        .eq('created_by', _uid)
        .maybeSingle();
    if (data == null) return null;
    return Employe.fromMap(data);
  }

  /// Enregistre la date de la visite médicale de démarrage.
  Future<void> marquerVisiteMedicale(String id, DateTime date) async {
    await _db
        .from('employes')
        .update({'visite_medicale_le': date.toIso8601String().substring(0, 10)})
        .eq('id', id)
        .eq('created_by', _uid);
  }

  /// Plan d'action (rempli par le N+1 quand l'employé est « à suivre »).
  Future<void> updatePlanAction(String id, String? texte) async {
    await _db
        .from('employes')
        .update({'plan_action': (texte?.trim().isEmpty ?? true) ? null : texte!.trim()})
        .eq('id', id)
        .eq('created_by', _uid);
  }

  /// Affectations en cours (date_fin null) de tous les marchés — pour les
  /// rappels de visite terrain.
  Future<List<Affectation>> getAffectationsActives() async {
    final data = await _db
        .from('affectations')
        .select('*, employes(nom, prenom, salaire_mensuel, part_patronale, frais_gestion_type, frais_gestion_montant, frais_gestion_pct), markets(numero)')
        .eq('created_by', _uid)
        .isFilter('date_fin', null)
        .order('date_debut');
    return (data as List).map((m) => Affectation.fromMap(m)).toList();
  }

  Future<Employe> create(Employe employe) async {
    final matricule = (employe.matricule?.isNotEmpty == true)
        ? employe.matricule!
        : await generateMatricule();
    final data = await _db
        .from('employes')
        .insert({
          ...employe.toInsertMap(),
          'matricule':  matricule,
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
        .eq('created_by', _uid)
        .select()
        .single();
    return Employe.fromMap(data);
  }

  Future<void> delete(String id) async {
    await _db.from('employes').delete().eq('id', id).eq('created_by', _uid);
  }

  /// Génère un matricule unique : [CODE_ENTREPRISE]-[ANNÉE]-[SEQ]
  Future<String> generateMatricule() async {
    final settings = await CompanySettingsService.getMySettings();
    final raw  = settings?.companyName ?? '';
    final clean = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final code  = clean.isNotEmpty
        ? clean.substring(0, min(3, clean.length))
        : 'EMP';
    final year = DateTime.now().year;
    final res  = await _db
        .from('employes')
        .select('id')
        .eq('created_by', _uid)
        .count();
    final seq  = (res.count + 1).toString().padLeft(3, '0');
    return '$code-$year-$seq';
  }

  // ── Affectations ──────────────────────────────────────────────────────────

  Future<List<Affectation>> getByMarket(String marketId) async {
    final data = await _db
        .from('affectations')
        .select('*, employes(nom, prenom, salaire_mensuel, part_patronale, frais_gestion_type, frais_gestion_montant, frais_gestion_pct)')
        .eq('market_id', marketId)
        .eq('created_by', _uid)
        .order('date_debut');
    return (data as List).map((m) => Affectation.fromMap(m)).toList();
  }

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
        .select('*, employes(nom, prenom, salaire_mensuel, part_patronale, frais_gestion_type, frais_gestion_montant, frais_gestion_pct), markets(numero)')
        .single();
    return Affectation.fromMap(data);
  }

  Future<void> terminerAffectation(String affectationId) async {
    await _db
        .from('affectations')
        .update({'date_fin': DateTime.now().toIso8601String().substring(0, 10)})
        .eq('id', affectationId)
        .eq('created_by', _uid);
  }

  Future<void> supprimerAffectation(String affectationId) async {
    await _db.from('affectations').delete()
        .eq('id', affectationId)
        .eq('created_by', _uid);
  }

  /// Coût total mensuel d'un marché (brut + patronale + frais pour chaque employé actif)
  Future<double> coutSalarialMarket(String marketId) async {
    final affectations = await getByMarket(marketId);
    return affectations
        .where((a) => a.enCours)
        .fold<double>(0, (sum, a) => sum + a.coutTotal);
  }
}
