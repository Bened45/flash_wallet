class AppConstants {
  // API
  static const String baseUrl = 'https://staging.bitcoinflash.xyz/api/v1';

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String tagKey = 'user_tag';
  static const String nameKey = 'user_name';
  static const String emailKey = 'user_email';
  static const String whatsappKey = 'user_whatsapp';
  static const String operatorKey = 'selected_operator';
  static const String operatorNumberKey = 'operator_number';
  static const String autoConvertKey = 'auto_convert';
  static const String thresholdKey = 'auto_convert_threshold';

  // Opérateurs Mobile Money
  static const List<Map<String, dynamic>> operators = [
    {
      'id': 'mtn',
      'name': 'MTN MoMo',
      'color': 0xFFFFCB05,
      'textColor': 0xFF000000,
      'prefix': '+229 97',
    },
    {
      'id': 'moov',
      'name': 'Moov Money',
      'color': 0xFF0052A5,
      'textColor': 0xFFFFFFFF,
      'prefix': '+229 95',
    },
    {
      'id': 'celtiis',
      'name': 'Celtiis',
      'color': 0xFFE30613,
      'textColor': 0xFFFFFFFF,
      'prefix': '+229 98',
    },
  ];

  // Pays
  static const String defaultCountry = 'BJ';

  // Conversion auto
  static const int defaultThresholdXof = 1000; // 1000 XOF minimum
  static const int pollingIntervalSeconds = 30; // Polling toutes les 30s
}