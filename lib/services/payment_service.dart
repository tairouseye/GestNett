import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment.dart';

class PaymentService {
  final _db = Supabase.instance.client.from('payments');
  String get _uid => Supabase.instance.client.auth.currentUser!.id;

  Future<Payment> add(Payment payment) async {
    final data = await _db
        .insert({
          ...payment.toInsertMap(),
          'created_at': DateTime.now().toIso8601String(),
          'created_by': _uid,
        })
        .select()
        .single();
    return Payment.fromMap(data);
  }

  Future<List<Payment>> getByInvoice(String invoiceId) async {
    final data = await _db
        .select()
        .eq('invoice_id', invoiceId)
        .eq('created_by', _uid)
        .order('date', ascending: false);
    return (data as List).map((m) => Payment.fromMap(m)).toList();
  }

  Future<void> delete(String id) =>
      _db.delete().eq('id', id).eq('created_by', _uid);

  /// Total encaissé pour un ensemble de factures — une seule requête.
  Future<double> totalForInvoices(List<String> invoiceIds) async {
    if (invoiceIds.isEmpty) return 0;
    final data = await _db
        .select('montant')
        .inFilter('invoice_id', invoiceIds)
        .eq('created_by', _uid);
    return (data as List)
        .fold<double>(0, (s, r) => s + ((r['montant'] as num?)?.toDouble() ?? 0));
  }

  /// Total encaissé par facture (id -> montant payé) — une seule requête.
  Future<Map<String, double>> totalsByInvoice(List<String> invoiceIds) async {
    if (invoiceIds.isEmpty) return {};
    final data = await _db
        .select('invoice_id, montant')
        .inFilter('invoice_id', invoiceIds)
        .eq('created_by', _uid);
    final map = <String, double>{};
    for (final r in (data as List)) {
      final id = r['invoice_id'] as String;
      map[id] = (map[id] ?? 0) + ((r['montant'] as num?)?.toDouble() ?? 0);
    }
    return map;
  }
}
