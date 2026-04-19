import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';

class FlashApi {
  static final FlashApi _instance = FlashApi._internal();
  factory FlashApi() => _instance;
  FlashApi._internal();

  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // JWT Token
        final token = await _storage.read(key: AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // Staging bypass
        final userId = await _storage.read(key: AppConstants.userIdKey);
        if (userId != null) {
          options.headers['X-Staging-User-Id'] = userId;
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        final statusCode = error.response?.statusCode;
        String message = 'Une erreur est survenue';

        if (statusCode == 401) {
          message = 'Email ou mot de passe incorrect';
        } else if (statusCode == 422) {
          final errors = error.response?.data['errors'];
          if (errors != null && errors is Map) {
            message = errors.values.first[0] ?? message;
          } else {
            message = error.response?.data['message'] ?? message;
          }
        } else if (statusCode == 500) {
          message = 'Erreur serveur — réessayez plus tard';
        } else {
          message = error.response?.data['message'] ?? message;
        }

        return handler.reject(DioException(
          requestOptions: error.requestOptions,
          message: message,
          response: error.response,
        ));
      },
    ));
  }

  // ── AUTH ──────────────────────────────

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String whatsapp,
    String country = 'BJ',
  }) async {
    final res = await _dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
      'whatsapp': whatsapp,
      'country': country,
    });

    // Sauvegarder user_id pour OTP et staging bypass
    final user = res.data['data']['user'];
    final userId = user['id'];
    await _storage.write(key: AppConstants.userIdKey, value: userId);
    await _storage.write(key: AppConstants.tagKey, value: user['tag'] ?? '');

    return res.data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    final data = res.data['data'];
    final token = data['token'];
    final user = data['user'];

    // Sauvegarder toutes les infos importantes
    await _storage.write(key: AppConstants.tokenKey, value: token);
    await _storage.write(key: AppConstants.userIdKey, value: user['id']);
    await _storage.write(key: AppConstants.tagKey, value: user['tag'] ?? '');
    await _storage.write(key: AppConstants.nameKey, value: user['name'] ?? '');
    await _storage.write(key: AppConstants.emailKey, value: user['email'] ?? '');
    await _storage.write(key: AppConstants.whatsappKey, value: user['whatsapp'] ?? '');

    return res.data;
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String userId,
    required String code,
  }) async {
    final res = await _dio.post('/auth/verify-otp', data: {
      'user_id': userId,
      'code': code,  // Important : 'code' pas 'otp'
    });
    return res.data;
  }

  Future<Map<String, dynamic>> regenerateOtp({
    required String userId,
  }) async {
    final res = await _dio.post('/auth/regenerate-otp', data: {
      'user_id': userId,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/auth/me');
    return res.data;
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
    await _storage.deleteAll();
  }

  // ── TRANSACTIONS ──────────────────────

  Future<Map<String, dynamic>> getTransactions() async {
    final res = await _dio.get('/transactions');
    return res.data;
  }

  Future<Map<String, dynamic>> createTransaction({
    required int amountXof,
    required String receiverAddress,
    required String type, // BUY_BITCOIN ou SELL_BITCOIN
    required String number,
  }) async {
    final res = await _dio.post('/transactions/create', data: {
      'amount': amountXof,
      'receiver_address': receiverAddress,
      'type': type,
      'number': number,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> buyBitcoin({
    required int amountXof,
    required String lightningAddress,
    required String mobileMoneyNumber,
  }) async {
    return createTransaction(
      amountXof: amountXof,
      receiverAddress: lightningAddress,
      type: 'BUY_BITCOIN',
      number: mobileMoneyNumber,
    );
  }

  Future<Map<String, dynamic>> sellBitcoin({
    required int amountXof,
    required String lightningAddress,
    required String mobileMoneyNumber,
  }) async {
    return createTransaction(
      amountXof: amountXof,
      receiverAddress: lightningAddress,
      type: 'SELL_BITCOIN',
      number: mobileMoneyNumber,
    );
  }

  Future<Map<String, dynamic>> getTransaction(String id) async {
    final res = await _dio.get('/transactions/$id');
    return res.data;
  }

  Future<Map<String, dynamic>> getTransactionSummary() async {
    final res = await _dio.get('/transactions/resume');
    return res.data;
  }

  Future<Map<String, dynamic>> getRemainingLimit() async {
    final res = await _dio.get('/transactions/remaining');
    return res.data;
  }

  Future<Map<String, dynamic>> getFlashbackStats() async {
    final res = await _dio.get('/transactions/flashback');
    return res.data;
  }

  // ── LIGHTNING PAYMENTS ──────────────────

  /// Send payment via Lightning Network
  Future<Map<String, dynamic>> sendLightningPayment({
    required String lightningAddress,
    required int amountSats,
    String? memo,
  }) async {
    final res = await _dio.post('/lightning/send', data: {
      'lightning_address': lightningAddress,
      'amount_sats': amountSats,
      if (memo != null) 'memo': memo,
    });
    return res.data;
  }

  /// Create Lightning invoice to receive payment
  /// Returns either the raw invoice string or a Map depending on API response
  Future<dynamic> createInvoice({
    required int amountSats,
    String? memo,
  }) async {
    // Use a separate Dio instance that accepts plain text responses
    final dioPlain = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      responseType: ResponseType.plain, // Accept plain text
    ));

    // Add auth headers manually
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token != null) {
      dioPlain.options.headers['Authorization'] = 'Bearer $token';
    }
    final userId = await _storage.read(key: AppConstants.userIdKey);
    if (userId != null) {
      dioPlain.options.headers['X-Staging-User-Id'] = userId;
    }

    try {
      final res = await dioPlain.post('/lightning/invoice', data: {
        'amount_sats': amountSats,
        if (memo != null) 'memo': memo,
      });
      final data = res.data;
      debugPrint('📡 API /lightning/invoice raw response: $data');
      debugPrint('📡 Response type: ${data.runtimeType}');

      // If it's a String, try to parse as JSON first
      if (data is String) {
        try {
          // Try JSON parse
          final json = jsonDecode(data);
          if (json is Map) return json;
        } catch (_) {
          // Not JSON, return raw string (the invoice)
          debugPrint('📡 Plain invoice string received');
          return data;
        }
      }
      return data;
    } catch (e) {
      debugPrint('❌ createInvoice API error: $e');
      rethrow;
    }
  }

  /// Pay a Lightning invoice
  Future<Map<String, dynamic>> payInvoice({
    required String invoice,
  }) async {
    final res = await _dio.post('/lightning/pay', data: {
      'invoice': invoice,
    });
    return res.data;
  }

  /// Decode Lightning invoice
  Future<Map<String, dynamic>> decodeInvoice(String invoice) async {
    final res = await _dio.post('/lightning/decode', data: {
      'invoice': invoice,
    });
    return res.data;
  }

  // ── STORAGE ───────────────────────────

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    return token != null;
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: AppConstants.userIdKey);
  }

  Future<String?> getTag() async {
    return await _storage.read(key: AppConstants.tagKey);
  }

  Future<String?> getLightningAddress() async {
    final tag = await _storage.read(key: AppConstants.tagKey);
    if (tag == null || tag.isEmpty) return null;
    return '$tag@bitcoinflash.xyz';
  }

  Future<Map<String, String?>> getUserInfo() async {
    return {
      'id': await _storage.read(key: AppConstants.userIdKey),
      'tag': await _storage.read(key: AppConstants.tagKey),
      'name': await _storage.read(key: AppConstants.nameKey),
      'email': await _storage.read(key: AppConstants.emailKey),
      'whatsapp': await _storage.read(key: AppConstants.whatsappKey),
    };
  }
}