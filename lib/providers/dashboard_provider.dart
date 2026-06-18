import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardStats {
  final int marchesActifs;
  final int nombreFactures;
  final double totalFacture;
  final double totalEncaisse;
  final double totalDepenses;
  final int clientsEnRetard;

  const DashboardStats({
    this.marchesActifs = 0,
    this.nombreFactures = 0,
    this.totalFacture = 0,
    this.totalEncaisse = 0,
    this.totalDepenses = 0,
    this.clientsEnRetard = 0,
  });

  double get beneficeEstime => totalEncaisse - totalDepenses;
  double get resteAEncaisser => totalFacture - totalEncaisse;
}

class MonthlyData {
  final String mois;
  final double montant;
  const MonthlyData(this.mois, this.montant);
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final supabase = Supabase.instance.client;
  final uid = supabase.auth.currentUser!.id;

  final results = await Future.wait<dynamic>([
    // Marchés actifs
    supabase.from('markets').select('id').eq('created_by', uid).eq('statut', 'en_cours').count(),
    // Factures (sauf annulées)
    supabase.from('invoices').select('total_ttc, statut, type_facture').eq('created_by', uid).neq('statut', 'annulee'),
    // Paiements
    supabase.from('payments').select('montant').eq('created_by', uid),
    // Dépenses
    supabase.from('expenses').select('montant').eq('created_by', uid),
    // Factures en retard (émises > 30 jours)
    supabase.from('invoices')
        .select('id')
        .eq('created_by', uid)
        .eq('statut', 'emise')
        .lt('date', DateTime.now().subtract(const Duration(days: 30)).toIso8601String().substring(0, 10))
        .count(),
  ]);

  final marchesActifs   = (results[0].count as int?) ?? 0;
  final invoicesList    = results[1] as List;
  final paymentsList    = results[2] as List;
  final expensesList    = results[3] as List;
  final clientsEnRetard = (results[4].count as int?) ?? 0;

  // Les proformas sont des devis : exclues du "facturé" réel et du "reste à encaisser".
  final totalFacture  = invoicesList
      .where((r) => r['type_facture'] != 'proforma')
      .fold<double>(0, (s, r) => s + ((r['total_ttc'] as num?)?.toDouble() ?? 0));
  final totalEncaisse = paymentsList.fold<double>(0, (s, r) => s + ((r['montant'] as num?)?.toDouble() ?? 0));
  final totalDepenses = expensesList.fold<double>(0, (s, r) => s + ((r['montant'] as num?)?.toDouble() ?? 0));

  return DashboardStats(
    marchesActifs:    marchesActifs,
    nombreFactures:   invoicesList.length,
    totalFacture:     totalFacture,
    totalEncaisse:    totalEncaisse,
    totalDepenses:    totalDepenses,
    clientsEnRetard:  clientsEnRetard,
  );
});

// Encaissements des 6 derniers mois — une seule requête au lieu de 6
final monthlyEncaissementsProvider = FutureProvider<List<MonthlyData>>((ref) async {
  final supabase = Supabase.instance.client;
  final uid = supabase.auth.currentUser!.id;
  final moisLabels = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];

  final now  = DateTime.now();
  final from = DateTime(now.year, now.month - 5, 1);

  final res = await supabase
      .from('payments')
      .select('montant, date')
      .eq('created_by', uid)
      .gte('date', from.toIso8601String().substring(0, 10))
      .lte('date', now.toIso8601String().substring(0, 10));

  // Agréger côté client par mois
  final Map<String, double> totaux = {};
  for (int i = 5; i >= 0; i--) {
    final t = DateTime(now.year, now.month - i, 1);
    final key = '${t.year}-${t.month.toString().padLeft(2, '0')}';
    totaux[key] = 0;
  }
  for (final row in (res as List)) {
    final date = row['date'] as String;
    final key  = date.substring(0, 7); // YYYY-MM
    if (totaux.containsKey(key)) {
      totaux[key] = totaux[key]! + ((row['montant'] as num?)?.toDouble() ?? 0);
    }
  }

  return totaux.entries.map((e) {
    final month = int.parse(e.key.split('-')[1]);
    return MonthlyData(moisLabels[month - 1], e.value);
  }).toList();
});
