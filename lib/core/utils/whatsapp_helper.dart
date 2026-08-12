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

  static String buildPaymentReminder({
    required String customerName,
    required double amount,
    required String invoiceDate,
    required String businessName,
    String? customMessage,
  }) {
    if (customMessage != null && customMessage.isNotEmpty) {
      return customMessage
          .replaceAll('{{CustomerName}}', customerName)
          .replaceAll('{{Amount}}', amount.toStringAsFixed(2))
          .replaceAll('{{InvoiceDate}}', invoiceDate)
          .replaceAll('{{BusinessName}}', businessName);
    }

    return '''Dear $customerName,

This is a friendly reminder that payment of ₹${amount.toStringAsFixed(2)} dated $invoiceDate is pending.

Kindly make payment at your earliest convenience.

Thank you.

$businessName''';
  }

  static String buildSecondReminder({
    required String customerName,
    required double amount,
    required String invoiceDate,
    required String businessName,
  }) {
    return '''Dear $customerName,

This is a second reminder that payment of ₹${amount.toStringAsFixed(2)} dated $invoiceDate is overdue.

Please make the payment immediately to avoid any inconvenience.

Thank you.

$businessName''';
  }

  static String buildFinalReminder({
    required String customerName,
    required double amount,
    required String invoiceDate,
    required String businessName,
  }) {
    return '''Dear $customerName,

This is a FINAL reminder that payment of ₹${amount.toStringAsFixed(2)} dated $invoiceDate is severely overdue.

Please clear the outstanding amount immediately to avoid further action.

Thank you.

$businessName''';
  }
}
