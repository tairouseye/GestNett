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
}
