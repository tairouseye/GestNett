import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice.dart';
import '../models/payment.dart';
import 'payment_service.dart';

/// Facture impayée avec son montant déjà encaissé et le reste dû.
class UnpaidInvoice {
  final Invoice invoice;
  final double paid;
  final double restant;
  const UnpaidInvoice({required this.invoice, required this.paid, required this.restant});

  int get joursRetard => DateTime.now().difference(invoice.echeance).inDays;
}

class InvoiceService {
  final _supabase = Supabase.instance.client;
  String get _uid => _supabase.auth.currentUser!.id;

  Future<List<Invoice>> getAll() async {
    final data = await _supabase
        .from('invoices')
        .select('*, clients(nom), markets(numero)')
        .eq('created_by', _uid)
        .order('created_at', ascending: false);
    return (data as List).map((m) => Invoice.fromMap(m)).toList();
  }

  Future<List<Invoice>> getByClient(String clientId) async {
    final data = await _supabase
        .from('invoices')
        .select('*, clients(nom), markets(numero)')
        .eq('client_id', clientId)
        .eq('created_by', _uid)
        .order('date', ascending: false);
    return (data as List).map((m) => Invoice.fromMap(m)).toList();
  }

  Future<Invoice?> getById(String id) async {
    final data = await _supabase
        .from('invoices')
        .select('*, clients(nom), markets(numero)')
        .eq('id', id)
        .eq('created_by', _uid)
        .maybeSingle();
    if (data == null) return null;
    return Invoice.fromMap(data);
  }

  Future<Invoice> create(Invoice invoice) async {
    // Numéro du marché : SONATEL-MRK001-2026
    final marketData = await _supabase
        .from('markets')
        .select('numero')
        .eq('id', invoice.marketId!)
        .single();
    final marketNumero = marketData['numero'] as String;

    // Séquence propre à ce marché → SONATEL-MRK001-2026-0001
    final seq = await _nextSequenceForMarket(invoice.marketId!);
    final numero = '$marketNumero-${seq.toString().padLeft(3, '0')}';

    final insertData = {
      ...invoice.toInsertMap(),
      'numero': numero,
      // Échéance par défaut : date + 30 jours si non précisée.
      'date_echeance': (invoice.dateEcheance ?? invoice.date.add(const Duration(days: 30)))
          .toIso8601String()
          .substring(0, 10),
      'created_at': DateTime.now().toIso8601String(),
      'created_by': _uid,
    };
    final data = await _supabase
        .from('invoices')
        .insert(insertData)
        .select('*, clients(nom), markets(numero)')
        .single();
    return Invoice.fromMap(data);
  }

  Future<void> updateEcheance(String id, DateTime date) async {
    await _supabase
        .from('invoices')
        .update({'date_echeance': date.toIso8601String().substring(0, 10)})
        .eq('id', id)
        .eq('created_by', _uid);
  }

  /// Duplique une facture (nouvelle date, statut émise, nouveau numéro).
  Future<Invoice> duplicate(Invoice src) async {
    return create(Invoice(
      id: '',
      numero: '',
      clientId: src.clientId,
      marketId: src.marketId,
      date: DateTime.now(),
      montantHt: src.montantHt,
      tvaPct: src.tvaPct,
      totalTtc: src.totalTtc,
      statut: InvoiceStatut.emise,
      typeFacture: src.typeFacture,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> updatePdfUrl(String id, String url) async {
    await _supabase
        .from('invoices')
        .update({'pdf_url': url, 'statut': 'emise'})
        .eq('id', id);
  }

  Future<void> updateStatut(String id, InvoiceStatut statut) async {
    await _supabase
        .from('invoices')
        .update({'statut': statut.value})
        .eq('id', id)
        .eq('created_by', _uid);
  }

  Future<Invoice> convertirEnDefinitive(String id) async {
    final data = await _supabase
        .from('invoices')
        .update({'type_facture': 'definitive'})
        .eq('id', id)
        .eq('created_by', _uid)
        .select('*, clients(nom), markets(numero)')
        .single();
    return Invoice.fromMap(data);
  }

  // Paiements liés
  Future<List<Payment>> getPayments(String invoiceId) async {
    final data = await _supabase
        .from('payments')
        .select()
        .eq('invoice_id', invoiceId)
        .order('date', ascending: false);
    return (data as List).map((m) => Payment.fromMap(m)).toList();
  }

  Future<double> getTotalPaid(String invoiceId) async {
    final payments = await getPayments(invoiceId);
    return payments.fold<double>(0.0, (sum, p) => sum + p.montant);
  }

  /// Factures définitives non soldées (émises ou acompte), avec reste dû > 0,
  /// triées de la plus ancienne à la plus récente.
  Future<List<UnpaidInvoice>> getUnpaid() async {
    final data = await _supabase
        .from('invoices')
        .select('*, clients(nom, telephone), markets(numero)')
        .eq('created_by', _uid)
        .eq('type_facture', 'definitive')
        .inFilter('statut', ['emise', 'payee_partiel'])
        .order('date', ascending: true);
    final invoices = (data as List).map((m) => Invoice.fromMap(m)).toList();
    final totals = await PaymentService()
        .totalsByInvoice(invoices.map((i) => i.id).toList());
    final result = <UnpaidInvoice>[];
    for (final inv in invoices) {
      final paid = totals[inv.id] ?? 0;
      final restant = inv.totalTtc - paid;
      if (restant > 0) {
        result.add(UnpaidInvoice(invoice: inv, paid: paid, restant: restant));
      }
    }
    return result;
  }

  Future<int> _nextSequenceForMarket(String marketId) async {
    final data = await _supabase
        .from('invoices')
        .select('id')
        .eq('market_id', marketId)
        .count();
    return data.count + 1;
  }
}
