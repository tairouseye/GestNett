import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense.dart';

class ExpenseService {
  final _db = Supabase.instance.client.from('expenses');

  Future<List<Expense>> getAll() async {
    final data = await _db
        .select('*, markets(numero)')
        .order('date', ascending: false);
    return (data as List).map((m) => Expense.fromMap(m)).toList();
  }

  Future<List<Expense>> getByMarket(String marketId) async {
    final data = await _db
        .select('*, markets(numero)')
        .eq('market_id', marketId)
        .order('date', ascending: false);
    return (data as List).map((m) => Expense.fromMap(m)).toList();
  }

  Future<double> getTotalByMarket(String marketId) async {
    final expenses = await getByMarket(marketId);
    return expenses.fold<double>(0.0, (sum, e) => sum + e.montant);
  }

  Future<Expense> add(Expense expense) async {
    final data = await _db
        .insert({
          ...expense.toInsertMap(),
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('*, markets(numero)')
        .single();
    return Expense.fromMap(data);
  }

  Future<void> delete(String id) => _db.delete().eq('id', id);
}
