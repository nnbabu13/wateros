class AppConstants {
  AppConstants._();

  // Supabase
  static const String supabaseUrl = 'https://vlqipfnmnwijbfueavcu.supabase.co';
  static const String supabasePublishableKey = 'sb_publishable_QNk5UbVBhQyVlrdRCwitEA_I244x2Na';

  // Hive Boxes
  static const String cacheBox = 'cache';
  static const String settingsBox = 'settings';

  // Cache Keys
  static const String userKey = 'current_user';
  static const String businessKey = 'current_business';
  static const String tokenKey = 'auth_token';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Currency
  static const String defaultCurrency = 'INR';
  static const String defaultCurrencySymbol = '₹';

  // Date Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy hh:mm a';
  static const String monthYearFormat = 'MMM yyyy';

  // Regex
  static const String phoneRegex = r'^[6-9]\d{9}$';
  static const String emailRegex = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String gstRegex = r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$';

  // Limits
  static const int maxProductNameLength = 100;
  static const int maxCustomerNameLength = 100;
  static const int maxNotesLength = 500;
}
