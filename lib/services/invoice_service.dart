import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice.dart';
import '../models/payment.dart';

class InvoiceService {
  final _supabase = Supabase.instance.client;
  String get _uid => _supabase.auth.currentUser!.id;

  Future<List<Invoice>> getAll() async {
    final data = await _supabase
        .from('invoices')
        .select('*, clients(nom)')
        .eq('created_by', _uid)
        .order('created_at', ascending: false);
    return (data as List).map((m) => Invoice.fromMap(m)).toList();
  }

  Future<List<Invoice>> getByClient(String clientId) async {
    final data = await _supabase
        .from('invoices')
        .select('*, clients(nom)')
        .eq('client_id', clientId)
        .order('date', ascending: false);
    return (data as List).map((m) => Invoice.fromMap(m)).toList();
  }

  Future<Invoice?> getById(String id) async {
    final data = await _supabase
        .from('invoices')
        .select('*, clients(nom)')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Invoice.fromMap(data);
  }

  Future<Invoice> create(Invoice invoice) async {
    final seq = await _nextSequence();
    final insertData = {
      ...invoice.toInsertMap(),
      'numero': 'FAC-${DateTime.now().year}-${seq.toString().padLeft(3, '0')}',
      'created_at': DateTime.now().toIso8601String(),
      'created_by': _uid,
    };
    final data = await _supabase
        .from('invoices')
        .insert(insertData)
        .select('*, clients(nom)')
        .single();
    return Invoice.fromMap(data);
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
        .eq('id', id);
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

  Future<int> _nextSequence() async {
    final year = DateTime.now().year;
    final data = await _supabase
        .from('invoices')
        .select('numero')
        .like('numero', 'FAC-$year-%')
        .order('numero', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return 1;
    final last = data['numero'] as String;
    final seq = int.tryParse(last.split('-').last) ?? 0;
    return seq + 1;
  }
}
