import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class Formatters {
  Formatters._();

  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: AppConstants.defaultCurrencySymbol,
    decimalDigits: 2,
  );

  static final _numberFormat = NumberFormat('#,##0.##', 'en_IN');
  static final _dateFormat = DateFormat(AppConstants.dateFormat);
  static final _dateTimeFormat = DateFormat(AppConstants.dateTimeFormat);
  static final _monthYearFormat = DateFormat(AppConstants.monthYearFormat);

  static String currency(double amount) {
    return _currencyFormat.format(amount);
  }

  static String number(double value) {
    return _numberFormat.format(value);
  }

  static String date(DateTime date) {
    return _dateFormat.format(date);
  }

  static String dateTime(DateTime date) {
    return _dateTimeFormat.format(date);
  }

  static String monthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }

  static String percentage(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  static String compact(double value) {
    if (value >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(1)}Cr';
    } else if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return _numberFormat.format(value);
  }

  static String phone(String phone) {
    if (phone.length == 10) {
      return '+91 ${phone.substring(0, 5)} ${phone.substring(5)}';
    }
    return phone;
  }

  static String invoiceNumber(String prefix, int counter) {
    return '$prefix-${counter.toString().padLeft(6, '0')}';
  }
}
