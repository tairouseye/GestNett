import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../services/payment_service.dart';

class InvoicesStats {
  final double caFacture;
  final double encaisse;
  final int nbDefinitives;
  final int nbProformas;
  final Map<InvoiceStatut, int> parStatut;
  final int nbEnRetard;
  final double montantEnRetard;

  const InvoicesStats({
    required this.caFacture,
    required this.encaisse,
    required this.nbDefinitives,
    required this.nbProformas,
    required this.parStatut,
    required this.nbEnRetard,
    required this.montantEnRetard,
  });

  double get reste => caFacture - encaisse;
  double get tauxRecouvrement => caFacture > 0 ? encaisse / caFacture : 0;
}

final invoicesStatsProvider = FutureProvider<InvoicesStats>((ref) async {
  final invoices = await InvoiceService().getAll();
  final paid = await PaymentService().totalsByInvoice(invoices.map((i) => i.id).toList());

  double caFacture = 0, encaisse = 0, montantRetard = 0;
  int nbDef = 0, nbPro = 0, nbRetard = 0;
  final parStatut = <InvoiceStatut, int>{};
  final now = DateTime.now();

  for (final i in invoices) {
    if (i.isProforma) {
      nbPro++;
      continue;
    }
    if (i.statut == InvoiceStatut.annulee) continue;
    nbDef++;
    caFacture += i.totalTtc;
    final p = paid[i.id] ?? 0;
    encaisse += p;
    parStatut[i.statut] = (parStatut[i.statut] ?? 0) + 1;
    final restant = i.totalTtc - p;
    if (restant > 0 && now.isAfter(i.echeance)) {
      nbRetard++;
      montantRetard += restant;
    }
  }

  return InvoicesStats(
    caFacture: caFacture,
    encaisse: encaisse,
    nbDefinitives: nbDef,
    nbProformas: nbPro,
    parStatut: parStatut,
    nbEnRetard: nbRetard,
    montantEnRetard: montantRetard,
  );
});
