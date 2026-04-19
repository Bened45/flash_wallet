import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lightning_service.dart';
import 'flash_api.dart';
import '../models/lightning_models.dart';

// ── Config Provider ────────────────────────
// Configure these values from Polar
class LightningConfig {
  final String lndRestUrl;  // e.g. http://10.0.2.2:8080 (emulator) or http://192.168.x.x:8080 (device)
  final String macaroonHex; // From Polar node settings

  const LightningConfig({
    required this.lndRestUrl,
    required this.macaroonHex,
  });
}

final lightningConfigProvider = StateProvider<LightningConfig?>((ref) => null);

// ── Lightning State ────────────────────────
class LightningState {
  final bool isConnected;
  final int balanceSats;
  final List<Invoice> invoices;
  final List<Map<String, dynamic>> payments;
  final String? error;
  final bool isLoading;

  const LightningState({
    this.isConnected = false,
    this.balanceSats = 0,
    this.invoices = const [],
    this.payments = const [],
    this.error,
    this.isLoading = false,
  });

  LightningState copyWith({
    bool? isConnected,
    int? balanceSats,
    List<Invoice>? invoices,
    List<Map<String, dynamic>>? payments,
    String? error,
    bool? isLoading,
  }) {
    return LightningState(
      isConnected: isConnected ?? this.isConnected,
      balanceSats: balanceSats ?? this.balanceSats,
      invoices: invoices ?? this.invoices,
      payments: payments ?? this.payments,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ── Lightning Notifier ────────────────────────
class LightningNotifier extends StateNotifier<LightningState> {
  final LightningService _service = LightningService();
  bool _initialized = false;

  LightningNotifier() : super(const LightningState());

  /// Initialize connection to LND node
  Future<void> initialize(String lndRestUrl, String macaroonHex) async {
    if (_initialized) return;
    state = state.copyWith(isLoading: true);

    try {
      _service.init(
        baseUrl: lndRestUrl,
        lndUrl: lndRestUrl,
        macaroon: LightningService.macaroonFromHex(macaroonHex),
      );
      _initialized = true;

      // Load initial data
      await Future.wait([
        _loadBalance(),
        _loadInvoices(),
        _loadPayments(),
      ]);

      state = state.copyWith(isConnected: true, isLoading: false);
      debugPrint('✅ LightningService connected to $lndRestUrl');
    } catch (e) {
      state = state.copyWith(
        error: 'Connection failed: $e',
        isLoading: false,
      );
      debugPrint('❌ LightningService init error: $e');
    }
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await _service.getBalance();
      state = state.copyWith(balanceSats: balance['in_channels'] ?? 0);
    } catch (_) {}
  }

  Future<void> _loadInvoices() async {
    try {
      final invoices = await _service.getInvoices(limit: 20);
      final parsed = invoices.map((i) => Invoice.fromJson(i)).toList();
      state = state.copyWith(invoices: parsed);
    } catch (_) {}
  }

  Future<void> _loadPayments() async {
    try {
      final payments = await _service.getPayments(limit: 20);
      state = state.copyWith(payments: payments);
    } catch (_) {}
  }

  // ── Public Methods ────────────────────────

  /// Create a new Lightning invoice
  Future<Invoice?> createInvoice({
    required int amountSats,
    String? memo,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final invoice = await _service.createInvoice(
        amountSats: amountSats,
        memo: memo,
      );
      await _loadInvoices();
      return invoice;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  /// Decode an invoice to preview details
  Future<Map<String, dynamic>?> decodeInvoice(String invoice) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final decoded = await _service.decodeInvoice(invoice);
      return decoded;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  /// Pay a Lightning invoice
  Future<PaymentResult?> payInvoice(String invoice) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _service.payInvoice(invoice);
      await Future.wait([_loadBalance(), _loadPayments()]);
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  /// Send payment to a Lightning Address
  Future<PaymentResult?> sendToAddress({
    required String lightningAddress,
    required int amountSats,
    String? memo,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _service.sendToAddress(
        lightningAddress: lightningAddress,
        amountSats: amountSats,
        memo: memo,
      );
      await Future.wait([_loadBalance(), _loadPayments()]);
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  /// Refresh all data
  Future<void> refresh() async {
    await Future.wait([
      _loadBalance(),
      _loadInvoices(),
      _loadPayments(),
    ]);
  }
}

final lightningProvider =
    StateNotifierProvider<LightningNotifier, LightningState>((ref) {
  return LightningNotifier();
});
