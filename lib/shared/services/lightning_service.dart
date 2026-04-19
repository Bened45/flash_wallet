import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../models/lightning_models.dart';

class LightningService {
  static final LightningService _instance = LightningService._internal();
  factory LightningService() => _instance;
  LightningService._internal();

  late Dio _dio;
  WebSocketChannel? _wsChannel;
  bool _isConnected = false;
  
  // Config - à mettre à jour avec les infos nodl
  String? _baseUrl;
  String? _lndUrl;
  String? _macaroon;
  bool _isInitialized = false;

  /// Initialize the service with nodl credentials
  void init({
    required String baseUrl,
    required String lndUrl,
    String? macaroon,
  }) {
    _baseUrl = baseUrl;
    _lndUrl = lndUrl;
    _macaroon = macaroon;

    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl!,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        if (_macaroon != null) 'Grpc-Metadata-macaroon': _macaroon,
      },
    ));

    // Accept self-signed certificates (for Polar dev nodes)
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return client;
    };

    _isInitialized = true;
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if WebSocket is connected
  bool get isConnected => _isConnected;

  // ── INVOICE CREATION ────────────────────────

  /// Create a Lightning invoice to receive payment
  Future<Invoice> createInvoice({
    required int amountSats,
    String? memo,
    Duration? expiry,
  }) async {
    _checkInitialized();

    try {
      final res = await _dio.post('/v1/invoices', data: {
        'value': amountSats,
        if (memo != null) 'memo': memo,
        if (expiry != null) 'expiry': expiry.inSeconds,
      });

      return Invoice.fromJson(res.data);
    } catch (e) {
      throw Exception('Failed to create invoice: $e');
    }
  }

  /// Check if an invoice has been paid
  Future<bool> isInvoicePaid(String paymentHash) async {
    _checkInitialized();

    try {
      final res = await _dio.get('/v1/invoice/$paymentHash');
      return res.data['settled'] == true;
    } catch (e) {
      return false;
    }
  }

  // ── SEND PAYMENTS ────────────────────────

  /// Pay a Lightning invoice
  Future<PaymentResult> payInvoice(String invoice) async {
    _checkInitialized();

    try {
      final res = await _dio.post('/v1/channels/transactions', data: {
        'payment_request': invoice,
      });

      return PaymentResult.fromJson(res.data);
    } catch (e) {
      return PaymentResult(
        success: false,
        error: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Send payment directly via keysend or to Lightning Address
  Future<PaymentResult> sendToAddress({
    required String lightningAddress,
    required int amountSats,
    String? memo,
  }) async {
    _checkInitialized();

    try {
      // First resolve the Lightning Address
      final lnurl = await resolveLightningAddress(lightningAddress);

      // Check if amount is within limits
      final amountMsats = amountSats * 1000;
      if (amountMsats < lnurl.minSendable || amountMsats > lnurl.maxSendable) {
        throw Exception(
          'Amount must be between ${lnurl.minSendableSats} and ${lnurl.maxSendableSats} sats',
        );
      }

      // Request invoice from callback
      final invoiceRes = await _dio.get(
        lnurl.callback,
        queryParameters: {
          'amount': amountMsats,
          if (memo != null) 'comment': memo,
        },
      );

      final invoice = invoiceRes.data['pr'] as String;

      // Pay the invoice
      return await payInvoice(invoice);
    } catch (e) {
      return PaymentResult(
        success: false,
        error: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Resolve a Lightning Address (LNURL-pay)
  Future<LNURLPayResponse> resolveLightningAddress(String address) async {
    final parts = address.split('@');
    if (parts.length != 2) {
      throw Exception('Invalid Lightning Address format');
    }

    final name = parts[0];
    final domain = parts[1];
    final url = 'https://$domain/.well-known/lnurlp/$name';

    try {
      final res = await Dio().get(url);
      return LNURLPayResponse.fromJson(res.data);
    } catch (e) {
      throw Exception('Failed to resolve Lightning Address: $e');
    }
  }

  /// Decode a Lightning invoice without paying
  Future<Map<String, dynamic>> decodeInvoice(String invoice) async {
    _checkInitialized();

    try {
      final res = await _dio.post('/v1/payreq/decode', data: {
        'pay_req': invoice,
      });

      return res.data;
    } catch (e) {
      throw Exception('Failed to decode invoice: $e');
    }
  }

  // ── WALLET & BALANCE ────────────────────────

  /// Get node wallet balance
  Future<Map<String, int>> getBalance() async {
    _checkInitialized();

    try {
      final res = await _dio.get('/v1/balance/blockchain');
      final channelRes = await _dio.get('/v1/balance/channels');

      return {
        'on_chain': res.data['confirmed_balance'] ?? 0,
        'in_channels': channelRes.data['balance'] ?? 0,
      };
    } catch (e) {
      return {'on_chain': 0, 'in_channels': 0};
    }
  }

  /// Get node information
  Future<NodeInfo> getNodeInfo() async {
    _checkInitialized();

    try {
      final res = await _dio.get('/v1/getinfo');
      return NodeInfo.fromJson(res.data);
    } catch (e) {
      throw Exception('Failed to get node info: $e');
    }
  }

  /// List active channels
  Future<List<Channel>> getChannels() async {
    _checkInitialized();

    try {
      final res = await _dio.get('/v1/channels');
      final channels = res.data['channels'] as List? ?? [];
      
      return channels
          .map((c) => Channel.fromJson(c))
          .where((ch) => ch.isActive)
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ── PAYMENT HISTORY ────────────────────────

  /// List recent payments
  Future<List<Map<String, dynamic>>> getPayments({
    int limit = 20,
    int? offset,
  }) async {
    _checkInitialized();

    try {
      final res = await _dio.get(
        '/v1/payments',
        queryParameters: {
          'max_payments': limit,
          'reversed': true,
          if (offset != null) 'index_offset': offset,
        },
      );

      return List<Map<String, dynamic>>.from(res.data['payments'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// List recent invoices
  Future<List<Map<String, dynamic>>> getInvoices({
    int limit = 20,
    bool pendingOnly = false,
  }) async {
    _checkInitialized();

    try {
      final res = await _dio.get(
        '/v1/invoices',
        queryParameters: {
          'num_max_invoices': limit,
          'reversed': true,
          if (pendingOnly) 'pending_only': true,
        },
      );

      return List<Map<String, dynamic>>.from(res.data['invoices'] ?? []);
    } catch (e) {
      return [];
    }
  }

  // ── WEBSOCKET LISTENER ────────────────────────

  /// Listen for incoming payments via WebSocket
  Stream<PaymentReceived> listenPayments() async* {
    if (_wsChannel != null) {
      await _wsChannel!.sink.close(ws_status.normalClosure);
    }

    final wsUrl = _baseUrl!.replaceFirst('https://', 'wss://').replaceFirst(
      'http://',
      'ws://',
    );

    _wsChannel = WebSocketChannel.connect(Uri.parse('$wsUrl/v1/invoices/subscribe'));

    try {
      await for (final message in _wsChannel!.stream) {
        if (message is String) {
          final data = jsonDecode(message);
          if (data['type'] == 'invoice_settled') {
            yield PaymentReceived(
              amountSats: data['value'] ?? 0,
              paymentHash: data['r_hash'] ?? '',
              memo: data['memo'],
              receivedAt: DateTime.now(),
            );
          }
        }
      }
      _isConnected = true;
    } catch (e) {
      _isConnected = false;
      yield* Stream.error(e);
    }
  }

  /// Disconnect WebSocket
  void disconnect() {
    _wsChannel?.sink.close(ws_status.normalClosure);
    _isConnected = false;
  }

  // ── HELPERS ────────────────────────

  void _checkInitialized() {
    if (!_isInitialized) {
      throw Exception(
        'LightningService not initialized. Call init() first with nodl credentials.',
      );
    }
  }

  /// Parse macaroon from hex string
  static String macaroonFromHex(String hex) {
    return base64.encode(hexStringToBytes(hex));
  }

  static List<int> hexStringToBytes(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
