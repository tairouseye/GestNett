import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../services/payment_service.dart';

class ClientStat {
  final double caFacture;
  final double encaisse;
  const ClientStat(this.caFacture, this.encaisse);
  double get impaye => caFacture - encaisse;
}

/// CA facturé / encaissé / impayé agrégé par client (clientId -> ClientStat).
final clientsStatsProvider = FutureProvider<Map<String, ClientStat>>((ref) async {
  final invoices = await InvoiceService().getAll();
  final dues = invoices
      .where((i) => !i.isProforma && i.statut != InvoiceStatut.annulee)
      .toList();
  final paid = await PaymentService().totalsByInvoice(dues.map((i) => i.id).toList());

  final ca = <String, double>{};
  final enc = <String, double>{};
  for (final i in dues) {
    ca[i.clientId] = (ca[i.clientId] ?? 0) + i.totalTtc;
    enc[i.clientId] = (enc[i.clientId] ?? 0) + (paid[i.id] ?? 0);
  }
  return {
    for (final id in ca.keys) id: ClientStat(ca[id] ?? 0, enc[id] ?? 0),
  };
});
