import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import 'auth_provider.dart';
import 'lnd_service.dart';
import 'wallet_provider.dart';

class AutoConvertSettings {
  final bool enabled;
  final double thresholdPercent; // Auto-convert when balance exceeds this %
  final String mobileMoneyOperator;
  final String mobileMoneyNumber;
  final bool convertAllOnReceive; // Convert 100% on every receive
  final double fixedAmountXof; // Fixed XOF amount to convert (if not convertAll)

  const AutoConvertSettings({
    this.enabled = false,
    this.thresholdPercent = 50.0,
    this.mobileMoneyOperator = 'MTN MoMo',
    this.mobileMoneyNumber = '',
    this.convertAllOnReceive = true,
    this.fixedAmountXof = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'thresholdPercent': thresholdPercent,
      'mobileMoneyOperator': mobileMoneyOperator,
      'mobileMoneyNumber': mobileMoneyNumber,
      'convertAllOnReceive': convertAllOnReceive,
      'fixedAmountXof': fixedAmountXof,
    };
  }

  factory AutoConvertSettings.fromJson(Map<String, dynamic> json) {
    return AutoConvertSettings(
      enabled: json['enabled'] as bool? ?? false,
      thresholdPercent: (json['thresholdPercent'] as num?)?.toDouble() ?? 50.0,
      mobileMoneyOperator: json['mobileMoneyOperator'] as String? ?? 'MTN MoMo',
      mobileMoneyNumber: json['mobileMoneyNumber'] as String? ?? '',
      convertAllOnReceive: json['convertAllOnReceive'] as bool? ?? true,
      fixedAmountXof: (json['fixedAmountXof'] as num?)?.toDouble() ?? 0,
    );
  }

  AutoConvertSettings copyWith({
    bool? enabled,
    double? thresholdPercent,
    String? mobileMoneyOperator,
    String? mobileMoneyNumber,
    bool? convertAllOnReceive,
    double? fixedAmountXof,
  }) {
    return AutoConvertSettings(
      enabled: enabled ?? this.enabled,
      thresholdPercent: thresholdPercent ?? this.thresholdPercent,
      mobileMoneyOperator: mobileMoneyOperator ?? this.mobileMoneyOperator,
      mobileMoneyNumber: mobileMoneyNumber ?? this.mobileMoneyNumber,
      convertAllOnReceive: convertAllOnReceive ?? this.convertAllOnReceive,
      fixedAmountXof: fixedAmountXof ?? this.fixedAmountXof,
    );
  }
}

class AutoConvertService {
  static const String _settingsKey = 'auto_convert_settings';

  /// Save auto-convert settings
  static Future<void> saveSettings(AutoConvertSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  /// Load auto-convert settings.
  /// Falls back to operator_number / selected_operator keys (OperatorSettingsScreen)
  /// when mobileMoneyNumber is empty inside the JSON blob.
  static Future<AutoConvertSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_settingsKey);

    AutoConvertSettings base;
    if (jsonString == null) {
      base = const AutoConvertSettings();
    } else {
      try {
        base = AutoConvertSettings.fromJson(
            jsonDecode(jsonString) as Map<String, dynamic>);
      } catch (_) {
        base = const AutoConvertSettings();
      }
    }

    // Si le numéro est absent du JSON, on tente la clé écrite par OperatorSettingsScreen.
    if (base.mobileMoneyNumber.isEmpty) {
      final fallbackNumber = prefs.getString(AppConstants.operatorNumberKey) ?? '';
      final fallbackOp = prefs.getString(AppConstants.operatorKey) ?? '';
      if (fallbackNumber.isNotEmpty) {
        base = base.copyWith(
          mobileMoneyNumber: fallbackNumber,
          mobileMoneyOperator: fallbackOp.isNotEmpty ? fallbackOp : base.mobileMoneyOperator,
        );
      }
    }

    return base;
  }

  /// Toggle auto-convert on/off
  static Future<void> toggleAutoConvert(bool enabled) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(enabled: enabled));
  }

  /// Check if should auto-convert based on current balance
  static Future<bool> shouldAutoConvert(int currentBalanceSats, int totalCapacitySats) async {
    final settings = await getSettings();
    if (!settings.enabled) return false;
    
    if (totalCapacitySats == 0) return false;
    
    final currentPercent = (currentBalanceSats / totalCapacitySats) * 100;
    return currentPercent >= settings.thresholdPercent;
  }

  /// Calculate amount to convert based on settings
  static Future<int> calculateConvertAmount(int balanceSats, double rateXof) async {
    final settings = await getSettings();
    
    if (settings.convertAllOnReceive) {
      // Convert entire balance
      return balanceSats;
    } else {
      // Convert fixed XOF amount
      if (settings.fixedAmountXof <= 0) return 0;
      return (settings.fixedAmountXof / rateXof).toInt();
    }
  }

  /// Get operator display info
  static String getOperatorInfo(AutoConvertSettings settings) {
    if (settings.mobileMoneyNumber.isEmpty) {
      return settings.mobileMoneyOperator;
    }
    return '${settings.mobileMoneyOperator} - ${settings.mobileMoneyNumber}';
  }
}

// ── AutoConvertState ──────────────────────────────────────────────────────────

class AutoConvertState {
  final bool enabled;
  final bool isConverting;
  final String? lastError;
  final DateTime? lastTriggered;

  const AutoConvertState({
    this.enabled = false,
    this.isConverting = false,
    this.lastError,
    this.lastTriggered,
  });

  AutoConvertState copyWith({
    bool? enabled,
    bool? isConverting,
    String? lastError,
    bool clearError = false,
    DateTime? lastTriggered,
  }) =>
      AutoConvertState(
        enabled: enabled ?? this.enabled,
        isConverting: isConverting ?? this.isConverting,
        lastError: clearError ? null : (lastError ?? this.lastError),
        lastTriggered: lastTriggered ?? this.lastTriggered,
      );
}

// ── AutoConvertNotifier ───────────────────────────────────────────────────────

class AutoConvertNotifier extends StateNotifier<AutoConvertState> {
  final Ref _ref;
  final LndService _lnd = LndService();
  Timer? _timer;
  final Set<String> _seenHashes = {};
  bool _firstPollDone = false;
  int _pollCount = 0;

  AutoConvertNotifier(this._ref) : super(const AutoConvertState()) {
    _init();
  }

  Future<void> _init() async {
    final settings = await AutoConvertService.getSettings();
    debugPrint('[AUTO] _init() — enabled=${settings.enabled}, '
        'number="${settings.mobileMoneyNumber}", '
        'operator="${settings.mobileMoneyOperator}"');
    state = state.copyWith(enabled: settings.enabled);
    if (settings.enabled) _startPolling();
  }

  /// Active ou désactive la conversion automatique.
  Future<void> setEnabled(bool enabled) async {
    debugPrint('[AUTO] setEnabled($enabled)');
    await AutoConvertService.toggleAutoConvert(enabled);
    state = state.copyWith(enabled: enabled);
    if (enabled) {
      _firstPollDone = false;
      _pollCount = 0;
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  /// Resynchronise l'état depuis SharedPreferences (après retour de l'écran de
  /// paramètres par exemple).
  Future<void> reload() async {
    final settings = await AutoConvertService.getSettings();
    debugPrint('[AUTO] reload() — enabled=${settings.enabled}, '
        'number="${settings.mobileMoneyNumber}"');
    final wasEnabled = state.enabled;
    state = state.copyWith(enabled: settings.enabled);
    if (settings.enabled && !wasEnabled) {
      _firstPollDone = false;
      _pollCount = 0;
      _startPolling();
    } else if (!settings.enabled && wasEnabled) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _timer?.cancel();
    debugPrint('[AUTO] ⏱ Timer démarré — interval ${AppConstants.pollingIntervalSeconds}s');
    _timer = Timer.periodic(
      const Duration(seconds: AppConstants.pollingIntervalSeconds),
      (_) => _poll(),
    );
    _poll(); // premier poll immédiat
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
    debugPrint('[AUTO] ⏹ Timer arrêté');
  }

  Future<void> _poll() async {
    if (!state.enabled) {
      debugPrint('[AUTO] _poll() ignoré — état désactivé');
      return;
    }

    _pollCount++;
    debugPrint('[AUTO] Poll #$_pollCount — vérification invoices LND...');

    final settings = await AutoConvertService.getSettings();
    debugPrint('[AUTO]   numéro MoMo: "${settings.mobileMoneyNumber}"');
    debugPrint('[AUTO]   opérateur: "${settings.mobileMoneyOperator}"');

    if (!settings.enabled) {
      debugPrint('[AUTO]   → settings.enabled=false, annulé');
      return;
    }
    if (settings.mobileMoneyNumber.isEmpty) {
      debugPrint('[AUTO]   → numéro MoMo vide, annulé — configurez-le dans les paramètres');
      return;
    }

    try {
      final invoices = await _lnd.listInvoices(limit: 50);
      final settled = invoices.where((i) => i.isPaid).toList();
      debugPrint('[AUTO]   invoices settlées: ${settled.length} / ${invoices.length}');

      for (final inv in settled) {
        if (inv.paymentHash.isEmpty) continue;
        final isNew = !_seenHashes.contains(inv.paymentHash);
        _seenHashes.add(inv.paymentHash);

        if (!_firstPollDone) {
          // Premier poll : remplir le cache uniquement.
          debugPrint('[AUTO]   (premier poll) hash mis en cache: ${inv.paymentHash.substring(0, 16)}...');
          continue;
        }

        if (!isNew) continue;

        debugPrint('[AUTO] 🆕 Nouvelle invoice: hash=${inv.paymentHash.substring(0, 16)}... '
            'amount=${inv.amountSats} sats');
        await _triggerSell(inv.amountSats, settings);
      }
    } catch (e, st) {
      debugPrint('[AUTO] ❌ Erreur poll #$_pollCount: $e');
      debugPrint('[AUTO]    Stack: $st');
    } finally {
      if (!_firstPollDone) {
        _firstPollDone = true;
        debugPrint('[AUTO]   Premier poll terminé — cache initialisé avec ${_seenHashes.length} hashes');
      }
    }
  }

  Future<void> _triggerSell(int amountSats, AutoConvertSettings settings) async {
    if (state.isConverting) {
      debugPrint('[AUTO] _triggerSell ignoré — conversion déjà en cours');
      return;
    }
    if (amountSats <= 0) {
      debugPrint('[AUTO] _triggerSell ignoré — amountSats=$amountSats');
      return;
    }

    debugPrint('[AUTO] 💱 _triggerSell — $amountSats sats → ${settings.mobileMoneyOperator} '
        '${settings.mobileMoneyNumber}');
    state = state.copyWith(isConverting: true, clearError: true);

    try {
      final rate = _ref.read(walletProvider).rateXof;
      final amountXof = (amountSats * rate).toInt();
      debugPrint('[AUTO]   taux: $rate XOF/sat → $amountXof XOF');

      if (amountXof <= 0) {
        debugPrint('[AUTO]   amountXof=0, annulé (taux non chargé ?)');
        state = state.copyWith(isConverting: false);
        return;
      }

      final flashApi = _ref.read(flashApiProvider);
      debugPrint('[AUTO]   → sellBitcoin($amountXof XOF, ${settings.mobileMoneyNumber})');
      final res = await flashApi.sellBitcoin(
        amountXof: amountXof,
        lightningAddress: 'benedoffice1@bitcoinflash.xyz',
        mobileMoneyNumber: settings.mobileMoneyNumber,
      );
      debugPrint('[AUTO]   sellBitcoin réponse: $res');

      final invoiceToPay = res['invoice'] as String?;

      if (invoiceToPay != null && invoiceToPay.isNotEmpty) {
        debugPrint('[AUTO] ⚡ Invoice reçue: ${invoiceToPay.substring(0, 40)}...');
        debugPrint('[AUTO] 💸 Paiement LND en cours...');
        await _lnd.payInvoice(invoiceToPay);
        debugPrint('[AUTO] ✅ Conversion complète !');
      } else {
        debugPrint('[AUTO] ⚠️  Champ "invoice" absent ou vide dans la réponse Flash');
        debugPrint('[AUTO]    Clés reçues: ${res.keys.toList()}');
      }

      await _ref.read(lndProvider.notifier).refresh();
      state = state.copyWith(
        isConverting: false,
        lastTriggered: DateTime.now(),
      );
    } catch (e, st) {
      debugPrint('[AUTO] ❌ _triggerSell erreur: $e');
      debugPrint('[AUTO]    Stack: $st');
      state = state.copyWith(isConverting: false, lastError: e.toString());
    }
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final autoConvertProvider =
    StateNotifierProvider<AutoConvertNotifier, AutoConvertState>(
  (ref) => AutoConvertNotifier(ref),
);
