import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'flash_api.dart';
import 'auth_provider.dart';

class WalletState {
  final int balanceSats;
  final double rateXof;
  final List<Map<String, dynamic>> transactions;
  final String? lightningAddress;
  final int remainingLimit;
  final bool isLoading;
  final String? error;

  const WalletState({
    this.balanceSats = 0,
    this.rateXof = 3.84,
    this.transactions = const [],
    this.lightningAddress,
    this.remainingLimit = 100,
    this.isLoading = false,
    this.error,
  });

  int get balanceXof => (balanceSats * rateXof).toInt();

  WalletState copyWith({
    int? balanceSats,
    double? rateXof,
    List<Map<String, dynamic>>? transactions,
    String? lightningAddress,
    int? remainingLimit,
    bool? isLoading,
    String? error,
  }) {
    return WalletState(
      balanceSats: balanceSats ?? this.balanceSats,
      rateXof: rateXof ?? this.rateXof,
      transactions: transactions ?? this.transactions,
      lightningAddress: lightningAddress ?? this.lightningAddress,
      remainingLimit: remainingLimit ?? this.remainingLimit,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  final FlashApi _api;

  WalletNotifier(this._api) : super(const WalletState());

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await Future.wait([
        _loadTransactions(),
        _loadRemainingLimit(),
        _loadUserInfo(),
      ]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final res = await _api.getTransactions();
      final txs = List<Map<String, dynamic>>.from(
        res['transactions'] ?? []);

      // Calculer le solde depuis les transactions
      int balanceSats = 0;
      double lastRate = 3.84;

      for (final tx in txs) {
        final rate = (tx['exchange_rate'] as num?)?.toDouble() ?? 54890457;
        // exchange_rate est en satoshis par XOF — inverser
        lastRate = 1 / (rate / 100000000);

        final amountXof = (tx['amount_xof'] as String?)
          ?.replaceAll(' XOF', '')
          .replaceAll(',', '') ?? '0';
        final xof = double.tryParse(amountXof) ?? 0;

        if (tx['type'] == 'BUY_BITCOIN' &&
            tx['status'] == 'COMPLETED') {
          balanceSats += (xof / lastRate).toInt();
        } else if (tx['type'] == 'SELL_BITCOIN' &&
            tx['status'] == 'COMPLETED') {
          balanceSats -= (xof / lastRate).toInt();
        }
      }

      state = state.copyWith(
        transactions: txs,
        balanceSats: balanceSats < 0 ? 0 : balanceSats,
        rateXof: lastRate,
      );
    } catch (e) {
      // Garder les données mock si erreur
    }
  }

  Future<void> _loadRemainingLimit() async {
    try {
      final res = await _api.getRemainingLimit();
      final remaining = res['remaining'] as int? ?? 100;
      state = state.copyWith(remainingLimit: remaining);
    } catch (_) {}
  }

  Future<void> _loadUserInfo() async {
    try {
      final res = await _api.getMe();
      final user = res['data']?['user'];
      if (user != null) {
        final email = user['email'] as String?;
        if (email != null) {
          state = state.copyWith(lightningAddress: email);
        }
      }
    } catch (_) {}
  }

  Future<String?> buyBitcoin({
    required int amountXof,
    required String lightningAddress,
    required String mobileMoneyNumber,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.buyBitcoin(
        amountXof: amountXof,
        lightningAddress: lightningAddress,
        mobileMoneyNumber: mobileMoneyNumber,
      );
      await loadAll();
      return res['transaction']?['id'];
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<String?> sellBitcoin({
    required int amountXof,
    required String lightningAddress,
    required String mobileMoneyNumber,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.sellBitcoin(
        amountXof: amountXof,
        lightningAddress: lightningAddress,
        mobileMoneyNumber: mobileMoneyNumber,
      );
      await loadAll();
      return res['transaction']?['id'];
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> sendLightningPayment({
    required String lightningAddress,
    required int amountSats,
    String? memo,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.sendLightningPayment(
        lightningAddress: lightningAddress,
        amountSats: amountSats,
        memo: memo,
      );
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // ── Lightning Invoice Methods ──────────────────

  /// Create a Lightning invoice to receive payment
  /// Returns the invoice string (payment request)
  Future<String?> createInvoice({
    required int amountSats,
    String? memo,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.createInvoice(
        amountSats: amountSats,
        memo: memo,
      );
      debugPrint('📥 createInvoice raw response: $res');
      debugPrint('📥 Response type: ${res.runtimeType}');

      await loadAll();

      // API might return different formats — handle all cases
      if (res is String) {
        // Direct string response (likely the invoice itself)
        return res;
      } else if (res is Map) {
        if (res['invoice'] is Map) {
          return res['invoice']['payment_request'] ?? res['invoice']['bolt11'];
        } else if (res['payment_request'] is String) {
          return res['payment_request'];
        } else if (res['invoice'] is String) {
          return res['invoice'];
        } else if (res['bolt11'] is String) {
          return res['bolt11'];
        } else if (res['data'] is Map) {
          final data = res['data'] as Map;
          if (data['invoice'] is Map) {
            return data['invoice']['payment_request'] ?? data['invoice']['bolt11'];
          } else if (data['payment_request'] is String) {
            return data['payment_request'];
          }
        }
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ createInvoice error: $e\n$stackTrace');
      state = state.copyWith(error: e.toString());
      return null;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Decode a Lightning invoice to preview payment details
  Future<Map<String, dynamic>?> decodeInvoice(String invoice) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.decodeInvoice(invoice);
      return res['invoice'] ?? res;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Pay a Lightning invoice
  Future<bool> payInvoice({required String invoice}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.payInvoice(invoice: invoice);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final walletProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref.watch(flashApiProvider));
});
