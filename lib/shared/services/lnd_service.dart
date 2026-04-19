import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lightning_models.dart';
import 'polar_config.dart';

// ── LndService ───────────────────────────────────────────────────────────────

/// Direct LND REST API client wired to Polar's Alice node.
///
/// • URL     : https://192.168.1.147:8081
/// • Auth    : admin.macaroon read from the host filesystem via [dart:io].
///             Falls back to [PolarConfig.macaroonHex] when the file is
///             unreachable (e.g. running on an Android device).
/// • TLS     : self-signed cert accepted — dev only, never ship to prod.
class LndService {
  static const String _baseUrl = 'https://192.168.1.148:8081';
  static const String _macaroonRelPath =
      '.polar/networks/1/volumes/lnd/alice'
      '/data/chain/bitcoin/regtest/admin.macaroon';

  late Dio _dio;
  bool _initialized = false;

  LndService._();
  static final LndService _instance = LndService._();
  factory LndService() => _instance;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _ensureInit() async {
    if (_initialized) return;
    final hex = await _readMacaroon();
    _dio = _buildDio(hex);
    _initialized = true;
  }

  /// Reads admin.macaroon bytes and converts them to a hex string.
  /// Falls back to [PolarConfig.macaroonHex] if the file cannot be read
  /// (wrong platform, path missing, permissions, etc.).
  static Future<String> _readMacaroon() async {
    final home = Platform.environment['HOME'] ?? '';
    final path = '$home/$_macaroonRelPath';
    final file = File(path);
    try {
      final bytes = await file.readAsBytes();
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      debugPrint('[LND] ✅ Macaroon lu depuis le fichier: $path');
      debugPrint('[LND]    Hex (20 premiers chars): ${hex.substring(0, 20)}...');
      return hex;
    } catch (e) {
      debugPrint('[LND] ⚠️  Fichier macaroon inaccessible ($path): $e');
      debugPrint('[LND]    → Fallback sur PolarConfig.macaroonHex');
      debugPrint('[LND]    Hex (20 premiers chars): ${PolarConfig.macaroonHex.substring(0, 20)}...');
      return PolarConfig.macaroonHex;
    }
  }

  static Dio _buildDio(String macaroonHex) {
    debugPrint('[LND] 🔧 Initialisation Dio → $_baseUrl');
    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Grpc-Metadata-macaroon': macaroonHex,
      },
    ));

    // Accept Polar's self-signed TLS certificate.
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return HttpClient()..badCertificateCallback = (cert, host, port) => true;
    };
    debugPrint('[LND] 🔐 TLS bypass activé (self-signed cert Polar accepté)');

    return dio;
  }

  // ── Node info ─────────────────────────────────────────────────────────────

  /// Returns live information about the Alice node.
  Future<NodeInfo> getInfo() async {
    await _ensureInit();
    debugPrint('[LND] → GET $_baseUrl/v1/getinfo');
    try {
      final res = await _dio.get('/v1/getinfo');
      final info = NodeInfo.fromJson(res.data as Map<String, dynamic>);
      debugPrint('[LND] ✅ getinfo OK — alias: ${info.alias}, pubkey: ${info.publicKey.substring(0, 16)}...');
      return info;
    } on DioException catch (e) {
      debugPrint('[LND] ❌ getinfo ERREUR: ${e.type} — ${e.message}');
      debugPrint('[LND]    Response: ${e.response?.statusCode} ${e.response?.data}');
      rethrow;
    }
  }

  // ── Balance ───────────────────────────────────────────────────────────────

  /// Returns the spendable (local) channel balance in satoshis.
  Future<int> getBalance() async {
    await _ensureInit();
    debugPrint('[LND] → GET $_baseUrl/v1/balance/channels');
    try {
      final res = await _dio.get('/v1/balance/channels');
      final data = res.data as Map<String, dynamic>;
      final bal = int.tryParse(data['balance']?.toString() ?? '0') ?? 0;
      debugPrint('[LND] ✅ balance: $bal sats');
      return bal;
    } on DioException catch (e) {
      debugPrint('[LND] ❌ getBalance ERREUR: ${e.type} — ${e.message}');
      debugPrint('[LND]    Response: ${e.response?.statusCode} ${e.response?.data}');
      rethrow;
    }
  }

  // ── Create invoice ────────────────────────────────────────────────────────

  /// Creates a BOLT11 invoice and returns the payment_request string.
  Future<String> createInvoice(int amountSats, String memo) async {
    await _ensureInit();
    final res = await _dio.post('/v1/invoices', data: {
      'value': amountSats,
      'memo': memo,
      'expiry': 3600, // 1 hour
    });
    final data = res.data as Map<String, dynamic>;
    final pr = data['payment_request'] as String?;
    if (pr == null || pr.isEmpty) {
      throw Exception('LND returned no payment_request');
    }
    return pr;
  }

  // ── Decode invoice ───────────────────────────────────────────────────────────

  /// Decodes a BOLT11 invoice without paying it.
  /// Returns LND fields: num_satoshis, description, expiry, payment_hash, etc.
  Future<Map<String, dynamic>> decodePayReq(String payReq) async {
    await _ensureInit();
    final res = await _dio.get('/v1/payreq/$payReq');
    return res.data as Map<String, dynamic>;
  }

  // ── Pay invoice ───────────────────────────────────────────────────────────

  /// Pays a BOLT11 invoice synchronously and returns a [PaymentResult].
  ///
  /// Uses a 2-minute receive timeout because LND blocks until the payment
  /// settles or the route fails.
  Future<PaymentResult> payInvoice(String paymentRequest) async {
    await _ensureInit();
    try {
      final res = await _dio.post(
        '/v1/channels/transactions',
        data: {'payment_request': paymentRequest},
        options: Options(receiveTimeout: const Duration(minutes: 2)),
      );
      final data = res.data as Map<String, dynamic>;
      final paymentError = data['payment_error'] as String? ?? '';
      if (paymentError.isNotEmpty) {
        return PaymentResult(
          success: false,
          error: paymentError,
          timestamp: DateTime.now(),
        );
      }
      return PaymentResult(
        success: true,
        paymentHash: _base64ToHex(data['payment_hash']),
        preimage: _base64ToHex(data['payment_preimage']),
        timestamp: DateTime.now(),
      );
    } on DioException catch (e) {
      // LND retourne l'erreur métier dans le corps JSON sous la clé "error".
      // Ex: {"error":"invoice is already paid","code":6}
      final lndError = e.response?.data is Map
          ? (e.response!.data as Map)['error']?.toString()
          : null;
      final statusCode = e.response?.statusCode;
      final msg = lndError ?? _friendlyLndError(statusCode, e.message);
      debugPrint('[LND] ❌ payInvoice HTTP $statusCode — $msg');
      return PaymentResult(
        success: false,
        error: msg,
        timestamp: DateTime.now(),
      );
    }
  }

  static String _friendlyLndError(int? code, String? raw) {
    switch (code) {
      case 400: return 'Requête invalide (invoice malformée ?)';
      case 404: return 'Invoice introuvable';
      case 500: return 'Erreur LND interne — vérifiez que Polar est démarré';
      default:  return raw?.split('\n').first ?? 'Erreur inconnue';
    }
  }

  // ── Invoice history ───────────────────────────────────────────────────────

  /// Lists received invoices, most recent first.
  Future<List<Invoice>> listInvoices({int limit = 25}) async {
    await _ensureInit();
    final res = await _dio.get('/v1/invoices', queryParameters: {
      'num_max_invoices': limit,
      'reversed': true,
    });
    final data = res.data as Map<String, dynamic>;
    final list = (data['invoices'] as List? ?? []).cast<Map<String, dynamic>>();
    return list.map(_invoiceFromLnd).toList();
  }

  // ── Payment history ───────────────────────────────────────────────────────

  /// Lists sent payments, most recent first.
  Future<List<Map<String, dynamic>>> listPayments({int limit = 25}) async {
    await _ensureInit();
    final res = await _dio.get('/v1/payments', queryParameters: {
      'max_payments': limit,
      'reversed': true,
    });
    final data = res.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['payments'] ?? []);
  }

  // ── Lightning Address (LNURL-pay) ─────────────────────────────────────────

  /// Resolves a Lightning Address (`user@domain`) via LNURL-pay and returns
  /// a BOLT11 invoice for [amountSats].
  ///
  /// Steps:
  ///   1. Fetch LNURL-pay metadata from `https://domain/.well-known/lnurlp/user`
  ///   2. Validate [amountSats] against minSendable / maxSendable
  ///   3. Call the callback URL to obtain a fresh invoice
  Future<String> resolveLightningAddress(
    String address,
    int amountSats,
  ) async {
    final parts = address.split('@');
    if (parts.length != 2) {
      throw ArgumentError('Invalid Lightning Address: $address');
    }
    final user = parts[0];
    final domain = parts[1];

    // Use a plain Dio instance — no LND auth, no TLS bypass needed here.
    final externalDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    // Step 1 — fetch LNURL-pay metadata
    final metaRes = await externalDio.get(
      'https://$domain/.well-known/lnurlp/$user',
    );
    final meta = metaRes.data as Map<String, dynamic>;

    final callback = meta['callback'] as String?;
    if (callback == null || callback.isEmpty) {
      throw Exception('LNURL-pay response has no callback URL');
    }

    final minSendable = (meta['minSendable'] as num?)?.toInt() ?? 1000;
    final maxSendable = (meta['maxSendable'] as num?)?.toInt() ?? 1000000000;
    final amountMsats = amountSats * 1000;

    if (amountMsats < minSendable || amountMsats > maxSendable) {
      throw Exception(
        'Amount out of range: $amountSats sats '
        '(min ${minSendable ~/ 1000} – max ${maxSendable ~/ 1000} sats)',
      );
    }

    // Step 2 — request invoice from callback
    final invoiceRes = await externalDio.get(
      callback,
      queryParameters: {'amount': amountMsats},
    );
    final invoiceData = invoiceRes.data as Map<String, dynamic>;
    final pr = invoiceData['pr'] as String?;
    if (pr == null || pr.isEmpty) {
      throw Exception('LNURL callback returned no invoice');
    }
    return pr;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Maps a raw LND invoice JSON object to [Invoice].
  ///
  /// LND REST encodes byte fields (r_hash, etc.) as base64.
  static Invoice _invoiceFromLnd(Map<String, dynamic> j) {
    final createdSec = int.tryParse(j['creation_date']?.toString() ?? '0') ?? 0;
    final settledSec = int.tryParse(j['settle_date']?.toString() ?? '0') ?? 0;
    final expirySec = int.tryParse(j['expiry']?.toString() ?? '3600') ?? 3600;

    return Invoice(
      paymentRequest: j['payment_request'] as String? ?? '',
      paymentHash: _base64ToHex(j['r_hash']),
      amountSats: int.tryParse(j['value']?.toString() ?? '0') ?? 0,
      memo: (j['memo'] as String?)?.isEmpty == true ? null : j['memo'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdSec * 1000),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        (createdSec + expirySec) * 1000,
      ),
      isPaid: j['settled'] == true,
      paidAt: settledSec > 0
          ? DateTime.fromMillisecondsSinceEpoch(settledSec * 1000)
          : null,
    );
  }

  /// Converts a base64-encoded byte value (as returned by LND REST) to hex.
  /// Returns the value unchanged if it's not valid base64.
  static String _base64ToHex(dynamic value) {
    if (value == null) return '';
    if (value is! String || value.isEmpty) return '';
    try {
      final bytes = base64Decode(value);
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (_) {
      return value;
    }
  }
}

// ── LndState ──────────────────────────────────────────────────────────────────

class LndState {
  final bool isLoading;
  final bool isConnected;
  final int balanceSats;
  final List<Invoice> invoices;
  final List<Map<String, dynamic>> payments;
  final String? error;

  const LndState({
    this.isLoading = false,
    this.isConnected = false,
    this.balanceSats = 0,
    this.invoices = const [],
    this.payments = const [],
    this.error,
  });

  LndState copyWith({
    bool? isLoading,
    bool? isConnected,
    int? balanceSats,
    List<Invoice>? invoices,
    List<Map<String, dynamic>>? payments,
    String? error,
    bool clearError = false,
  }) {
    return LndState(
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      balanceSats: balanceSats ?? this.balanceSats,
      invoices: invoices ?? this.invoices,
      payments: payments ?? this.payments,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── LndNotifier ───────────────────────────────────────────────────────────────

class LndNotifier extends StateNotifier<LndState> {
  final LndService _lnd = LndService();

  LndNotifier() : super(const LndState()) {
    refresh();
  }

  /// Loads balance, invoices, and payments in parallel.
  Future<void> refresh() async {
    debugPrint('[LND] 🔄 refresh() — connexion à Polar Alice...');
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _lnd.getBalance(),
        _lnd.listInvoices(),
        _lnd.listPayments(),
      ]);
      debugPrint('[LND] ✅ Connexion OK — balance: ${results[0]} sats, '
          '${(results[1] as List).length} invoices, '
          '${(results[2] as List).length} payments');
      state = LndState(
        isLoading: false,
        isConnected: true,
        balanceSats: results[0] as int,
        invoices: results[1] as List<Invoice>,
        payments: results[2] as List<Map<String, dynamic>>,
      );
    } catch (e) {
      debugPrint('[LND] ❌ refresh() ÉCHEC: $e');
      state = state.copyWith(
        isLoading: false,
        isConnected: false,
        error: e.toString(),
      );
    }
  }

  /// Creates an invoice and refreshes the invoice list.
  /// Returns the BOLT11 payment_request, or null on error.
  Future<String?> createInvoice(int amountSats, String memo) async {
    try {
      final pr = await _lnd.createInvoice(amountSats, memo);
      await _reloadInvoices();
      return pr;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Pays an invoice and refreshes balance + payment history on success.
  Future<PaymentResult> payInvoice(String paymentRequest) async {
    state = state.copyWith(isLoading: true, clearError: true);
    late PaymentResult result;
    try {
      result = await _lnd.payInvoice(paymentRequest);
      if (result.success) {
        await Future.wait([_reloadBalance(), _reloadPayments()]);
      }
    } catch (e) {
      result = PaymentResult(
        success: false,
        error: e.toString(),
        timestamp: DateTime.now(),
      );
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
    return result;
  }

  // ── Private reload helpers ─────────────────────────────────────────────────

  Future<void> _reloadBalance() async {
    try {
      state = state.copyWith(balanceSats: await _lnd.getBalance());
    } catch (_) {}
  }

  Future<void> _reloadInvoices() async {
    try {
      state = state.copyWith(invoices: await _lnd.listInvoices());
    } catch (_) {}
  }

  Future<void> _reloadPayments() async {
    try {
      state = state.copyWith(payments: await _lnd.listPayments());
    } catch (_) {}
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Main provider — exposes the full [LndState].
final lndProvider = StateNotifierProvider<LndNotifier, LndState>(
  (ref) => LndNotifier(),
);

/// Convenience slice — spendable balance in sats.
final lndBalanceProvider = Provider<int>(
  (ref) => ref.watch(lndProvider).balanceSats,
);

/// Convenience slice — received invoices list.
final lndInvoicesProvider = Provider<List<Invoice>>(
  (ref) => ref.watch(lndProvider).invoices,
);

/// Convenience slice — sent payments list.
final lndPaymentsProvider = Provider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(lndProvider).payments,
);
