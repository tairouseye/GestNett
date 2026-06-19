import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/evaluation.dart';

class EvaluationService {
  final _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  Future<List<Evaluation>> getByEmploye(String employeId) async {
    final data = await _db
        .from('evaluations')
        .select('*, markets(numero)')
        .eq('employe_id', employeId)
        .eq('created_by', _uid)
        .order('date', ascending: false);
    return (data as List).map((m) => Evaluation.fromMap(m)).toList();
  }

  Future<Evaluation> add(Evaluation e) async {
    final data = await _db
        .from('evaluations')
        .insert({
          ...e.toInsertMap(),
          'created_by': _uid,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('*, markets(numero)')
        .single();
    final created = Evaluation.fromMap(data);
    await _recomputeASuivre(e.employeId);
    return created;
  }

  Future<void> delete(String id, String employeId) async {
    await _db.from('evaluations').delete().eq('id', id).eq('created_by', _uid);
    await _recomputeASuivre(employeId);
  }

  /// (employeId|marketId) ayant au moins une évaluation superviseur — pour les
  /// rappels « visite terrain à faire ».
  Future<Set<String>> getSuperviseurEvalKeys() async {
    final data = await _db
        .from('evaluations')
        .select('employe_id, market_id')
        .eq('created_by', _uid)
        .eq('type', 'superviseur');
    return (data as List)
        .map((r) => '${r['employe_id']}:${r['market_id']}')
        .toSet();
  }

  /// Recalcule `a_suivre` (note finale pondérée < seuil) à partir des dernières
  /// évaluations superviseur et client de l'employé.
  Future<void> _recomputeASuivre(String employeId) async {
    final evals = await getByEmploye(employeId); // triées date desc
    double? sup, cli;
    for (final ev in evals) {
      if (ev.type == EvaluationType.superviseur) {
        sup ??= ev.score;
      } else {
        cli ??= ev.score;
      }
    }
    final note = noteFinale(scoreSuperviseur: sup, scoreClient: cli);
    final aSuivre    = note != null && note < kNoteFaibleSeuil;
    final aValoriser = note != null && note >= kNoteExcellentSeuil;
    await _db
        .from('employes')
        .update({'a_suivre': aSuivre, 'a_valoriser': aValoriser})
        .eq('id', employeId)
        .eq('created_by', _uid);
  }
}
