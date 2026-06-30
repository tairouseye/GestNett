import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recurrence.dart';
import '../models/invoice.dart';
import 'invoice_service.dart';

class RecurrenceService {
  final _supabase = Supabase.instance.client;
  String get _uid => _supabase.auth.currentUser!.id;

  Future<List<Recurrence>> getAll() async {
    final data = await _supabase
        .from('recurrences')
        .select('*, markets(numero), clients(nom)')
        .eq('created_by', _uid)
        .order('prochaine_date', ascending: true);
    return (data as List).map((m) => Recurrence.fromMap(m)).toList();
  }

  Future<Recurrence?> getById(String id) async {
    final data = await _supabase
        .from('recurrences')
        .select('*, markets(numero), clients(nom)')
        .eq('id', id)
        .eq('created_by', _uid)
        .maybeSingle();
    if (data == null) return null;
    return Recurrence.fromMap(data);
  }

  Future<Recurrence> create(Recurrence r) async {
    final data = await _supabase
        .from('recurrences')
        .insert({
          ...r.toInsertMap(),
          'created_at': DateTime.now().toIso8601String(),
          'created_by': _uid,
        })
        .select('*, markets(numero), clients(nom)')
        .single();
    return Recurrence.fromMap(data);
  }

  Future<void> update(String id, Map<String, dynamic> values) async {
    await _supabase
        .from('recurrences')
        .update(values)
        .eq('id', id)
        .eq('created_by', _uid);
  }

  Future<void> setActif(String id, bool actif) async {
    await update(id, {'actif': actif});
  }

  Future<void> delete(String id) async {
    await _supabase
        .from('recurrences')
        .delete()
        .eq('id', id)
        .eq('created_by', _uid);
  }

  /// Génère les factures dues pour toutes les récurrences échues.
  /// Retourne le nombre de factures créées.
  Future<int> genererEchues() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = today.toIso8601String().substring(0, 10);

    final rows = await _supabase
        .from('recurrences')
        .select('*, markets(numero), clients(nom)')
        .eq('created_by', _uid)
        .eq('actif', true)
        .lte('prochaine_date', todayStr);

    final recurrences = (rows as List).map((m) => Recurrence.fromMap(m)).toList();
    if (recurrences.isEmpty) return 0;

    final invoiceService = InvoiceService();
    var totalCreated = 0;

    for (final r in recurrences) {
      // Claim atomique : une seule génération par récurrence et par jour, tous
      // appareils confondus (compte partagé). Si un autre appareil l'a déjà
      // générée aujourd'hui, on passe.
      final claimed = await _supabase.rpc(
        'claim_recurrence',
        params: {'p_id': r.id, 'p_today': todayStr},
      );
      if (claimed != true) continue;

      var prochaine = r.prochaineDate;
      var generatedForThis = false;
      var safety = 0;

      while (!prochaine.isAfter(today) && safety < 24) {
        safety++;
        final inv = Invoice(
          id: '',
          numero: '',
          marketId: r.marketId,
          clientId: r.clientId,
          date: prochaine,
          montantHt: r.montantHt,
          tvaPct: r.tvaPct,
          totalTtc: r.totalTtc,
          statut: InvoiceStatut.emise,
          typeFacture: r.typeFacture,
          createdAt: DateTime.now(),
        );
        await invoiceService.create(inv);
        totalCreated++;
        generatedForThis = true;
        prochaine = addMonths(prochaine, r.frequence.mois, r.jourDuMois);
      }

      if (generatedForThis) {
        await update(r.id, {
          'prochaine_date': prochaine.toIso8601String().substring(0, 10),
          'derniere_generation': todayStr,
        });
      }
    }

    return totalCreated;
  }

  /// Ajoute [months] mois à [from] en plaçant le jour à [jour] (borné au
  /// dernier jour du mois cible, et au max 28 par construction).
  @visibleForTesting
  static DateTime addMonths(DateTime from, int months, int jour) {
    final total = from.year * 12 + (from.month - 1) + months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = jour > lastDay ? lastDay : jour;
    return DateTime(year, month, day);
  }
}
