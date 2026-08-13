import 'package:supabase_flutter/supabase_flutter.dart';

class CashTransactionHelper {
  /// Records a cash inflow (sale or customer payment).
  /// [referenceId] must be the payment.id (NOT sale.id).
  static Future<void> recordCashIn({
    required String businessId,
    required double amount,
    required String referenceType,
    required String referenceId,
    required String description,
    required DateTime transactionDate,
  }) async {
    final client = Supabase.instance.client;
    await client.from('cash_transactions').insert({
      'business_id': businessId,
      'transaction_type': 'in',
      'amount': amount,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'description': description,
      'transaction_date':
          '${transactionDate.year}-${transactionDate.month.toString().padLeft(2, '0')}-${transactionDate.day.toString().padLeft(2, '0')}',
    });
  }

  /// Records a cash outflow (expense).
  /// [referenceId] must be the expense.id.
  static Future<void> recordCashOut({
    required String businessId,
    required double amount,
    required String referenceId,
    required String description,
    required DateTime transactionDate,
  }) async {
    final client = Supabase.instance.client;
    await client.from('cash_transactions').insert({
      'business_id': businessId,
      'transaction_type': 'out',
      'amount': amount,
      'reference_type': 'expense',
      'reference_id': referenceId,
      'description': description,
      'transaction_date':
          '${transactionDate.year}-${transactionDate.month.toString().padLeft(2, '0')}-${transactionDate.day.toString().padLeft(2, '0')}',
    });
  }

  /// Deletes cash_transactions rows by reference type and id.
  static Future<void> deleteByReference({
    required String referenceType,
    required String referenceId,
  }) async {
    final client = Supabase.instance.client;
    await client
        .from('cash_transactions')
        .delete()
        .eq('reference_type', referenceType)
        .eq('reference_id', referenceId);
  }

  /// Deletes all cash_transactions for a sale.
  /// Queries payments linked to the sale, then deletes by each payment.id.
  static Future<void> deleteAllForSale(String saleId) async {
    final client = Supabase.instance.client;
    final payments = await client
        .from('payments')
        .select('id')
        .eq('sale_id', saleId);

    for (final p in payments) {
      final paymentId = p['id'] as String;
      await client
          .from('cash_transactions')
          .delete()
          .eq('reference_type', 'sale')
          .eq('reference_id', paymentId);
    }
  }

  /// Deletes all cash_transactions for a sale using old reference model (sale.id).
  /// Used during migration cleanup only.
  static Future<void> deleteLegacySaleReferences(String saleId) async {
    final client = Supabase.instance.client;
    await client
        .from('cash_transactions')
        .delete()
        .eq('reference_type', 'sale')
        .eq('reference_id', saleId);
  }
}
