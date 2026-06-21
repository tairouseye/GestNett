import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../services/expense_service.dart';
import '../services/payment_service.dart';

class MarketStat {
  final double facture;   // factures définitives non annulées
  final double encaisse;  // paiements reçus
  final double depenses;
  const MarketStat(this.facture, this.encaisse, this.depenses);

  double get resteAEncaisser => facture - encaisse;
  double get margeEncaisse => encaisse - depenses;
  double avancement(double contrat) => contrat > 0 ? (facture / contrat).clamp(0, 2).toDouble() : 0;
}

/// Agrégats par marché (marketId -> MarketStat).
final marketsStatsProvider = FutureProvider<Map<String, MarketStat>>((ref) async {
  final invoices = await InvoiceService().getAll();
  final expenses = await ExpenseService().getAll();

  final dues = invoices
      .where((i) =>
          i.marketId != null &&
          !i.isProforma &&
          i.statut != InvoiceStatut.annulee)
      .toList();
  final paid = await PaymentService().totalsByInvoice(dues.map((i) => i.id).toList());

  final fac = <String, double>{};
  final enc = <String, double>{};
  final dep = <String, double>{};
  for (final i in dues) {
    final m = i.marketId!;
    fac[m] = (fac[m] ?? 0) + i.totalTtc;
    enc[m] = (enc[m] ?? 0) + (paid[i.id] ?? 0);
  }
  for (final e in expenses) {
    if (e.marketId != null) {
      dep[e.marketId!] = (dep[e.marketId!] ?? 0) + e.montant;
    }
  }

  final keys = {...fac.keys, ...dep.keys};
  return {for (final k in keys) k: MarketStat(fac[k] ?? 0, enc[k] ?? 0, dep[k] ?? 0)};
});
