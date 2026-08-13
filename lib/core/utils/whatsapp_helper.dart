import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppHelper {
  WhatsAppHelper._();

  static Future<void> openWhatsApp({
    required String phoneNumber,
    required String message,
  }) async {
    final cleanedPhone = phoneNumber.replaceAll(RegExp(r'[\s\-+]'), '');
    final phone = cleanedPhone.startsWith('91')
        ? cleanedPhone
        : '91$cleanedPhone';

    final encodedMessage = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$phone?text=$encodedMessage');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch WhatsApp');
    }
  }

  /// Generates a mobile-friendly payment reminder message for WhatsApp.
  ///
  /// [currentSale] - the current sale map with keys: invoice_date, items (list)
  /// [customerName] - customer name
  /// [total] - total amount of current sale
  /// [paid] - paid amount of current sale
  /// [balance] - balance amount of current sale
  /// [customerTotalBalance] - total outstanding balance across all sales
  /// [previousSales] - list of previous unpaid sales, each with 'items' key
  static String generatePaymentReminderMessage({
    required String customerName,
    required String invoiceDate,
    required double total,
    required double paid,
    required double balance,
    required double customerTotalBalance,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> previousSales,
  }) {
    final buffer = StringBuffer();
    final rupee = String.fromCharCode(8377);
    final dateStr = DateFormat('dd MMM yyyy').format(DateTime.parse(invoiceDate));

    buffer.writeln('*Payment Reminder*');
    buffer.writeln('');
    buffer.writeln('📅 $dateStr');
    buffer.writeln('👤 $customerName');

    // Current order items
    if (items.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('*Order Details*');
      buffer.writeln('');

      for (final item in items) {
        final name = item['product_name'] as String? ?? '';
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        final rate = (item['unit_price'] as num?)?.toDouble() ?? 0;
        final amt = (item['total_amount'] as num?)?.toDouble() ?? 0;
        buffer.writeln('• $name');
        buffer.writeln('  ${qty.toStringAsFixed(0)} × $rupee${rate.toStringAsFixed(0)} = *$rupee${amt.toStringAsFixed(0)}*');
      }
    }

    // Current order totals
    buffer.writeln('');
    buffer.writeln('*Total Amount:* $rupee${total.toStringAsFixed(0)}');
    buffer.writeln('*Paid:* $rupee${paid.toStringAsFixed(0)}');

    if (balance > 0) {
      buffer.writeln('');
      buffer.writeln('🔴 *Balance Due: $rupee${balance.toStringAsFixed(0)}*');
    }

    // Previous unpaid orders
    if (previousSales.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('*Pending Orders*');
      buffer.writeln('');

      for (final prev in previousSales) {
        final prevDateStr = prev['invoice_date'] as String? ?? '';
        final prevDate = DateTime.tryParse(prevDateStr);
        final prevFormattedDate = prevDate != null ? DateFormat('dd MMM yyyy').format(prevDate) : prevDateStr;
        final prevItems = prev['items'] as List<dynamic>? ?? [];
        final prevTotal = (prev['total_amount'] as num?)?.toDouble() ?? 0;
        final prevBalance = (prev['balance_amount'] as num?)?.toDouble() ?? 0;

        buffer.writeln('📅 $prevFormattedDate');

        if (prevItems.length == 1) {
          final item = prevItems[0];
          final name = item['product_name'] as String? ?? '';
          final amt = (item['total_amount'] as num?)?.toDouble() ?? 0;
          buffer.writeln('• $name — *$rupee${amt.toStringAsFixed(0)}*');
        } else {
          for (final item in prevItems) {
            final name = item['product_name'] as String? ?? '';
            final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
            final rate = (item['unit_price'] as num?)?.toDouble() ?? 0;
            final amt = (item['total_amount'] as num?)?.toDouble() ?? 0;
            buffer.writeln('• $name');
            buffer.writeln('  ${qty.toStringAsFixed(0)} × $rupee${rate.toStringAsFixed(0)} = *$rupee${amt.toStringAsFixed(0)}*');
          }
          buffer.writeln('*Order Total: $rupee${prevTotal.toStringAsFixed(0)}*');
        }
        buffer.writeln('');
      }

      buffer.writeln('🔴 *Total Due: $rupee${customerTotalBalance.toStringAsFixed(0)}*');
    }

    return buffer.toString();
  }
}
