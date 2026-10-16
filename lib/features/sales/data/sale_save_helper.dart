import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/cash_transaction_helper.dart';

class SaleLineInput {
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double discountPercent;
  final double gstRate;

  const SaleLineInput({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
    this.gstRate = 0,
  });

  double get discountAmount =>
      unitPrice * quantity * discountPercent / 100;
  double get taxableAmount => (unitPrice * quantity) - discountAmount;
  double get gstAmount => taxableAmount * gstRate / 100;
  double get lineTotal => taxableAmount + gstAmount;
}

class SalePaymentInput {
  final String mode;
  final double amount;

  const SalePaymentInput({this.mode = 'cash', this.amount = 0});
}

class SaleSaveHelper {
  static String _localInvoiceNumber() {
    final now = DateTime.now();
    final counter = now.millisecondsSinceEpoch % 1000000;
    return 'INV-${counter.toString().padLeft(6, '0')}';
  }

  static Future<String> createSale({
    required String businessId,
    required String customerId,
    required DateTime invoiceDate,
    required List<SaleLineInput> items,
    required List<SalePaymentInput> payments,
    String? notes,
  }) async {
    final validItems = items
        .where((item) => item.productId.isNotEmpty && item.quantity > 0)
        .toList();
    if (validItems.isEmpty) {
      throw Exception('Please add at least one product');
    }

    final subtotal =
        validItems.fold<double>(0, (sum, item) => sum + item.unitPrice * item.quantity);
    final totalDiscount =
        validItems.fold<double>(0, (sum, item) => sum + item.discountAmount);
    final totalGst =
        validItems.fold<double>(0, (sum, item) => sum + item.gstAmount);
    final grandTotal =
        validItems.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final paidAmount = payments.fold<double>(0, (sum, e) => sum + e.amount);

    String status;
    if (paidAmount >= grandTotal) {
      status = 'paid';
    } else if (paidAmount > 0) {
      status = 'partially_paid';
    } else {
      status = 'pending';
    }

    String paymentMode;
    final validPayments = payments.where((e) => e.amount > 0).toList();
    if (validPayments.isEmpty) {
      paymentMode = 'cash';
    } else if (validPayments.length == 1) {
      paymentMode = validPayments.first.mode;
    } else {
      paymentMode = 'multiple';
    }

    final saleData = {
      'business_id': businessId,
      'customer_id': customerId,
      'invoice_date': DateFormat('yyyy-MM-dd').format(invoiceDate),
      'subtotal': subtotal,
      'discount_amount': totalDiscount,
      'discount_percent': 0,
      'tax_amount': totalGst,
      'total_amount': grandTotal,
      'paid_amount': paidAmount,
      'balance_amount': grandTotal - paidAmount,
      'payment_mode': paymentMode,
      'status': status,
      'notes': (notes == null || notes.isEmpty) ? null : notes,
    };

    final saleResponse = await Supabase.instance.client
        .from('sales')
        .insert(saleData)
        .select()
        .single();

    final saleId = saleResponse['id'] as String;

    for (final item in validItems) {
      final itemData = {
        'sale_id': saleId,
        'product_id': item.productId,
        'product_name': item.productName,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'discount_amount': item.discountAmount,
        'gst_rate': item.gstRate,
        'gst_amount': item.gstAmount,
        'total_amount': item.lineTotal,
      };
      await Supabase.instance.client.from('sale_items').insert(itemData);
    }

    for (final payment in payments) {
      final amt = payment.amount;
      if (amt <= 0) continue;

      final mode = payment.mode;

      final paymentResponse = await Supabase.instance.client
          .from('payments')
          .insert({
            'business_id': businessId,
            'customer_id': customerId,
            'sale_id': saleId,
            'amount': amt,
            'payment_mode': mode,
            'payment_date': DateFormat('yyyy-MM-dd').format(invoiceDate),
          })
          .select()
          .single();
      final paymentId = paymentResponse['id'] as String;

      if (mode == 'cash') {
        await CashTransactionHelper.recordCashIn(
          businessId: businessId,
          amount: amt,
          referenceType: 'sale',
          referenceId: paymentId,
          description: 'Sale ${_localInvoiceNumber()}',
          transactionDate: invoiceDate,
        );
      } else if (mode == 'upi' || mode == 'bank_transfer') {
        final bankAccounts = await Supabase.instance.client
            .from('bank_accounts')
            .select('id')
            .eq('business_id', businessId)
            .eq('is_active', true)
            .limit(1);
        if (bankAccounts.isNotEmpty) {
          final accId = bankAccounts[0]['id'] as String;
          final acc = await Supabase.instance.client
              .from('bank_accounts')
              .select('balance')
              .eq('id', accId)
              .single();
          final currentBal = (acc['balance'] as num?)?.toDouble() ?? 0;
          await Supabase.instance.client
              .from('bank_accounts')
              .update({'balance': currentBal + amt})
              .eq('id', accId);

          await Supabase.instance.client.from('bank_transactions').insert({
            'business_id': businessId,
            'bank_account_id': accId,
            'transaction_type': 'in',
            'amount': amt,
            'reference_type': 'sale',
            'reference_id': saleId,
            'description':
                'Sale ${_localInvoiceNumber()} (${mode.toUpperCase()})',
            'transaction_date': DateFormat('yyyy-MM-dd').format(invoiceDate),
          });
        }
      }
    }

    final balanceAmount = grandTotal - paidAmount;
    if (balanceAmount > 0 && customerId.isNotEmpty) {
      try {
        final custData = await Supabase.instance.client
            .from('customers')
            .select('current_balance')
            .eq('id', customerId)
            .single();
        final currentBal = (custData['current_balance'] as num?)?.toDouble() ?? 0;
        await Supabase.instance.client
            .from('customers')
            .update({'current_balance': currentBal + balanceAmount})
            .eq('id', customerId);
      } catch (_) {}
    }

    return saleId;
  }
}
