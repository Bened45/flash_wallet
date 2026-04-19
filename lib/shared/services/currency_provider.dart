import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lnd_service.dart';
import 'wallet_provider.dart';

// ── Devises supportées ────────────────────────────────────────────────────────

enum DisplayCurrency { xof, eur, usd, sats }

extension DisplayCurrencyExt on DisplayCurrency {
  String get code {
    switch (this) {
      case DisplayCurrency.xof: return 'XOF';
      case DisplayCurrency.eur: return 'EUR';
      case DisplayCurrency.usd: return 'USD';
      case DisplayCurrency.sats: return 'sats';
    }
  }

  String get symbol {
    switch (this) {
      case DisplayCurrency.xof: return 'XOF';
      case DisplayCurrency.eur: return '€';
      case DisplayCurrency.usd: return '\$';
      case DisplayCurrency.sats: return 'sats';
    }
  }

  String get label {
    switch (this) {
      case DisplayCurrency.xof: return 'Franc CFA (XOF)';
      case DisplayCurrency.eur: return 'Euro (EUR)';
      case DisplayCurrency.usd: return 'Dollar US (USD)';
      case DisplayCurrency.sats: return 'Satoshis (sats)';
    }
  }

  String get flag {
    switch (this) {
      case DisplayCurrency.xof: return '🇧🇯';
      case DisplayCurrency.eur: return '🇪🇺';
      case DisplayCurrency.usd: return '🇺🇸';
      case DisplayCurrency.sats: return '₿';
    }
  }

  static DisplayCurrency fromCode(String code) {
    return DisplayCurrency.values.firstWhere(
      (c) => c.code == code,
      orElse: () => DisplayCurrency.xof,
    );
  }
}

// ── State ─────────────────────────────────────────────────────────────────────

class CurrencyState {
  final DisplayCurrency selected;
  final double usdPerSat;   // fetched from CoinGecko
  final bool isFetchingRate;

  // XOF/EUR est un taux fixe officiel (accord de Bretton Woods révisé)
  static const double xofPerEur = 655.957;

  const CurrencyState({
    this.selected = DisplayCurrency.xof,
    this.usdPerSat = 0.0,
    this.isFetchingRate = false,
  });

  CurrencyState copyWith({
    DisplayCurrency? selected,
    double? usdPerSat,
    bool? isFetchingRate,
  }) => CurrencyState(
    selected: selected ?? this.selected,
    usdPerSat: usdPerSat ?? this.usdPerSat,
    isFetchingRate: isFetchingRate ?? this.isFetchingRate,
  );

  /// Convertit [sats] dans la devise sélectionnée.
  /// [rateXof] = XOF par satoshi (depuis walletProvider).
  double convert(int sats, double rateXof) {
    switch (selected) {
      case DisplayCurrency.xof:
        return sats * rateXof;
      case DisplayCurrency.eur:
        return (sats * rateXof) / xofPerEur;
      case DisplayCurrency.usd:
        return usdPerSat > 0 ? sats * usdPerSat : (sats * rateXof) / xofPerEur * 1.08;
      case DisplayCurrency.sats:
        return sats.toDouble();
    }
  }

  /// Formate [sats] en chaîne prête à l'affichage.
  String format(int sats, double rateXof) {
    final value = convert(sats, rateXof);
    switch (selected) {
      case DisplayCurrency.sats:
        return '${_fmt(sats)} sats';
      case DisplayCurrency.xof:
        return '${_fmt(value.toInt())} XOF';
      case DisplayCurrency.eur:
        return '€ ${value.toStringAsFixed(2)}';
      case DisplayCurrency.usd:
        return '\$ ${value.toStringAsFixed(2)}';
    }
  }

  /// Formate uniquement la valeur sans le symbole.
  String formatValue(int sats, double rateXof) {
    final value = convert(sats, rateXof);
    switch (selected) {
      case DisplayCurrency.sats:
        return _fmt(sats);
      case DisplayCurrency.xof:
        return _fmt(value.toInt());
      case DisplayCurrency.eur:
      case DisplayCurrency.usd:
        return value.toStringAsFixed(2);
    }
  }

  static String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]} ',
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

const _prefKey = 'display_currency';

class CurrencyNotifier extends StateNotifier<CurrencyState> {
  CurrencyNotifier() : super(const CurrencyState()) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    final currency = saved != null
        ? DisplayCurrencyExt.fromCode(saved)
        : DisplayCurrency.xof;
    state = state.copyWith(selected: currency);
    await _fetchUsdRate();
  }

  Future<void> select(DisplayCurrency currency) async {
    state = state.copyWith(selected: currency);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, currency.code);
    if (currency == DisplayCurrency.usd && state.usdPerSat == 0) {
      await _fetchUsdRate();
    }
  }

  Future<void> _fetchUsdRate() async {
    state = state.copyWith(isFetchingRate: true);
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
      final res = await dio.get(
        'https://api.coingecko.com/api/v3/simple/price',
        queryParameters: {'ids': 'bitcoin', 'vs_currencies': 'usd'},
      );
      final btcUsd = (res.data['bitcoin']['usd'] as num).toDouble();
      final usdPerSat = btcUsd / 100000000;
      debugPrint('[CURRENCY] BTC/USD: \$$btcUsd → $usdPerSat USD/sat');
      state = state.copyWith(usdPerSat: usdPerSat, isFetchingRate: false);
    } catch (e) {
      debugPrint('[CURRENCY] Impossible de récupérer BTC/USD: $e');
      state = state.copyWith(isFetchingRate: false);
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final currencyProvider =
    StateNotifierProvider<CurrencyNotifier, CurrencyState>(
  (_) => CurrencyNotifier(),
);

/// Raccourci : valeur formatée du solde LND dans la devise choisie.
final formattedBalanceProvider = Provider<String>((ref) {
  final currency = ref.watch(currencyProvider);
  final rateXof = ref.watch(walletProvider).rateXof;
  final sats = ref.watch(lndBalanceProvider);
  return currency.format(sats, rateXof);
});
