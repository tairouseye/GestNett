import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardStats {
  final int marchesActifs;
  final double totalFacture;
  final double totalEncaisse;
  final double totalDepenses;
  final int clientsEnRetard;

  const DashboardStats({
    this.marchesActifs = 0,
    this.totalFacture = 0,
    this.totalEncaisse = 0,
    this.totalDepenses = 0,
    this.clientsEnRetard = 0,
  });

  double get beneficeEstime => totalEncaisse - totalDepenses;

  DashboardStats copyWith({
    int? marchesActifs,
    double? totalFacture,
    double? totalEncaisse,
    double? totalDepenses,
    int? clientsEnRetard,
  }) => DashboardStats(
    marchesActifs: marchesActifs ?? this.marchesActifs,
    totalFacture: totalFacture ?? this.totalFacture,
    totalEncaisse: totalEncaisse ?? this.totalEncaisse,
    totalDepenses: totalDepenses ?? this.totalDepenses,
    clientsEnRetard: clientsEnRetard ?? this.clientsEnRetard,
  );
}

// Données pour le graphique des encaissements mensuels
class MonthlyData {
  final String mois;
  final double montant;
  const MonthlyData(this.mois, this.montant);
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final supabase = Supabase.instance.client;

  // Marchés actifs
  final marchesRes = await supabase
      .from('markets')
      .select('id')
      .eq('statut', 'en_cours')
      .count();
  final marchesActifs = marchesRes.count;

  // Total facturé (invoices émises + payées)
  final invoicesRes = await supabase
      .from('invoices')
      .select('total_ttc')
      .inFilter('statut', ['emise', 'payee']);
  final totalFacture = (invoicesRes as List)
      .fold<double>(0, (s, r) => s + ((r['total_ttc'] as num?)?.toDouble() ?? 0));

  // Total encaissé (sum payments)
  final paymentsRes = await supabase.from('payments').select('montant');
  final totalEncaisse = (paymentsRes as List)
      .fold<double>(0, (s, r) => s + ((r['montant'] as num?)?.toDouble() ?? 0));

  // Total dépenses
  final expensesRes = await supabase.from('expenses').select('montant');
  final totalDepenses = (expensesRes as List)
      .fold<double>(0, (s, r) => s + ((r['montant'] as num?)?.toDouble() ?? 0));

  // Clients en retard (factures émises > 30 jours sans paiement complet)
  final retardDate = DateTime.now().subtract(const Duration(days: 30));
  final retardRes = await supabase
      .from('invoices')
      .select('id')
      .eq('statut', 'emise')
      .lt('date', retardDate.toIso8601String().substring(0, 10))
      .count();
  final clientsEnRetard = retardRes.count;

  return DashboardStats(
    marchesActifs: marchesActifs,
    totalFacture: totalFacture,
    totalEncaisse: totalEncaisse,
    totalDepenses: totalDepenses,
    clientsEnRetard: clientsEnRetard,
  );
});

// Encaissements des 6 derniers mois pour le graphique
final monthlyEncaissementsProvider = FutureProvider<List<MonthlyData>>((ref) async {
  final supabase = Supabase.instance.client;
  final months = <MonthlyData>[];
  final moisLabels = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];

  final now = DateTime.now();
  for (int i = 5; i >= 0; i--) {
    final target = DateTime(now.year, now.month - i, 1);
    final from = DateTime(target.year, target.month, 1);
    final to = DateTime(target.year, target.month + 1, 0);

    final res = await supabase
        .from('payments')
        .select('montant')
        .gte('date', from.toIso8601String().substring(0, 10))
        .lte('date', to.toIso8601String().substring(0, 10));

    final total = (res as List)
        .fold<double>(0, (s, r) => s + ((r['montant'] as num?)?.toDouble() ?? 0));

    months.add(MonthlyData(moisLabels[target.month - 1], total));
  }

  return months;
});
