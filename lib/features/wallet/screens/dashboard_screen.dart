import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/services/auth_provider.dart';
import '../../../shared/services/auto_convert_service.dart';
import '../../../shared/services/lnd_service.dart';
import '../../../shared/services/payment_address_cache.dart';
import '../../../shared/services/currency_provider.dart';
import '../../../shared/services/wallet_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/skeleton_widgets.dart';
import '../../../shared/widgets/tx_detail_sheet.dart';
import '../../convert/screens/auto_convert_settings_screen.dart';
import '../../settings/screens/operator_settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const Color _primary = Color(0xFF1C28F0);
  static const Color _primaryLight = Color(0xFFEEF0FF);
  static const Color _success = Color(0xFF00B96B);
  static const Color _error = Color(0xFFE83333);
  static const Color _border = Color(0xFFE8E8F4);

  Map<String, String> _addressCache = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF1C28F0),
      statusBarIconBrightness: Brightness.light,
    ));
    Future.microtask(() {
      ref.read(walletProvider.notifier).loadAll();
      ref.read(lndProvider.notifier).refresh();
    });
    _loadAddressCache();
  }

  Future<void> _loadAddressCache() async {
    final cache = await PaymentAddressCache.loadAll();
    if (mounted) setState(() => _addressCache = cache);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final walletState = ref.watch(walletProvider);
    final lndState = ref.watch(lndProvider);
    final lndBalance = ref.watch(lndBalanceProvider);
    final lndInvoices = ref.watch(lndInvoicesProvider);
    final lndPayments = ref.watch(lndPaymentsProvider);
    final autoConvertEnabled = ref.watch(autoConvertProvider).enabled;
    final currency = ref.watch(currencyProvider);
    final formattedBalance = ref.watch(formattedBalanceProvider);

    // Hauteur totale de l'en-tête (barre système + contenu fixe) + débordement du banner (28px) + espacement (16px)
    final topPad = MediaQuery.of(context).padding.top;
    final scrollTopPadding = topPad + 358.0; // topPad + 290(header) + 28(banner) + 40(spacing)
    final scrollBottomPadding = MediaQuery.of(context).padding.bottom + 80.0;

    final scrollContent = walletState.isLoading && walletState.transactions.isEmpty
        ? DashboardSkeleton(scrollTopPadding: scrollTopPadding)
        : SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, scrollTopPadding, 16, scrollBottomPadding),
            child: Column(
              children: [
                _buildAutoConvert(autoConvertEnabled),
                const SizedBox(height: 20),
                _buildSectionHeader('OPÉRATEURS', 'Modifier',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OperatorSettingsScreen()),
                    )),
                const SizedBox(height: 10),
                _buildOperators(),
                const SizedBox(height: 20),
                _buildSectionHeader('HISTORIQUE', 'Voir tout',
                    onAction: () => context.push(AppRoutes.history)),
                const SizedBox(height: 10),
                ..._buildHistory(
                  lndInvoices: lndInvoices,
                  lndPayments: lndPayments,
                  flashTxs: walletState.transactions,
                  lndLoading: lndState.isLoading,
                ),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: Stack(
        children: [
          // Scroll content en arrière-plan (peint en premier)
          scrollContent,
          // Header peint en dernier = toujours au premier plan
          Positioned(
            top: 0, left: 0, right: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _buildHeader(context, authState, walletState, lndBalance, lndState, currency),
                Positioned(
                  bottom: -28, left: 16, right: 16,
                  child: _buildRateBanner(walletState),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Affichage du solde selon la devise choisie ────────────────────────────

  Widget _buildBalanceAmount(CurrencyState currency, int sats, double rateXof) {
    if (currency.selected == DisplayCurrency.sats) {
      return Text.rich(TextSpan(children: [
        TextSpan(
          text: _formatNum(sats),
          style: const TextStyle(
            color: Colors.white, fontSize: 44,
            fontWeight: FontWeight.w900, letterSpacing: -1)),
        const TextSpan(
          text: ' sats',
          style: TextStyle(
            color: Colors.white60, fontSize: 22, fontWeight: FontWeight.w400)),
      ]));
    }
    final value = currency.convert(sats, rateXof);
    final isDecimal = currency.selected == DisplayCurrency.eur ||
        currency.selected == DisplayCurrency.usd;
    final displayStr = isDecimal
        ? value.toStringAsFixed(2)
        : _formatNum(value.toInt());
    return Text.rich(TextSpan(children: [
      if (currency.selected == DisplayCurrency.eur ||
          currency.selected == DisplayCurrency.usd)
        TextSpan(
          text: '${currency.selected.symbol} ',
          style: const TextStyle(
            color: Colors.white60, fontSize: 22, fontWeight: FontWeight.w400)),
      TextSpan(
        text: displayStr,
        style: const TextStyle(
          color: Colors.white, fontSize: 44,
          fontWeight: FontWeight.w900, letterSpacing: -1)),
      if (currency.selected == DisplayCurrency.xof)
        const TextSpan(
          text: ' XOF',
          style: TextStyle(
            color: Colors.white60, fontSize: 22, fontWeight: FontWeight.w400)),
    ]));
  }

  Widget _buildBalanceSubline(CurrencyState currency, int sats, double rateXof) {
    // La sous-ligne montre toujours l'équivalent dans l'autre unité principale
    if (currency.selected == DisplayCurrency.sats) {
      final xof = (sats * rateXof).toInt();
      return Text('≈ ${_formatNum(xof)} XOF',
        style: const TextStyle(
          color: Color(0xFF7EFF9E), fontSize: 15, fontWeight: FontWeight.w600));
    }
    if (currency.selected == DisplayCurrency.xof) {
      return Text('≈ ${_formatNum(sats)} sats',
        style: const TextStyle(
          color: Color(0xFF7EFF9E), fontSize: 15, fontWeight: FontWeight.w600));
    }
    // EUR ou USD → montrer en XOF aussi
    final xof = (sats * rateXof).toInt();
    return Text('≈ ${_formatNum(xof)} XOF',
      style: const TextStyle(
        color: Color(0xFF7EFF9E), fontSize: 15, fontWeight: FontWeight.w600));
  }

  Widget _buildLndIndicator(LndState lndState) {
    final isConnected = lndState.isConnected;
    final isLoading = lndState.isLoading;
    final color = isLoading
        ? Colors.orange
        : isConnected
            ? const Color(0xFF00FF88)
            : const Color(0xFFFF4444);
    final label = isLoading ? 'LND...' : isConnected ? 'LND' : 'LND ✕';
    return Tooltip(
      message: isLoading
          ? 'Connexion Polar en cours...'
          : isConnected
              ? 'Polar Alice connecté (192.168.1.147:8081)'
              : 'LND déconnecté — ${lndState.error ?? "vérifiez Polar"}',
      child: GestureDetector(
        onTap: () => ref.read(lndProvider.notifier).refresh(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.6), width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              )),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthState authState,
      WalletState walletState, int lndBalance, LndState lndState,
      CurrencyState currency) {
    final lndLoading = lndState.isLoading;
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              child: CustomPaint(painter: _CurvesPainter()),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar
                Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.flash_on,
                      color: _primary, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text('FLASH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    )),
                  const SizedBox(width: 10),
                  _buildLndIndicator(lndState),
                  const Spacer(),
                  Stack(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 20),
                    ),
                  ]),
                  const SizedBox(width: 8),
                  // Avatar avec initiales réelles
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4)),
                    ),
                    child: Center(
                      child: Text(authState.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        )),
                    ),
                  ),
                ]),

                // Solde
                const SizedBox(height: 28),
                const Text('SOLDE TOTAL',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  )),
                const SizedBox(height: 6),
                lndLoading && lndBalance == 0
                  ? const Text('...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                      ))
                  : _buildBalanceAmount(currency, lndBalance, walletState.rateXof),
                const SizedBox(height: 4),
                _buildBalanceSubline(currency, lndBalance, walletState.rateXof),

                // Boutons
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: _actionBtn(
                    'assets/icons/ic_receive.svg', 'Recevoir', true,
                    () => context.go(AppRoutes.receive))),
                  const SizedBox(width: 8),
                  Expanded(child: _actionBtn(
                    'assets/icons/ic_send.svg', 'Envoyer', false,
                    () => context.go(AppRoutes.send))),
                  const SizedBox(width: 8),
                  Expanded(child: _actionBtn(
                    'assets/icons/ic_convert.svg', 'Convertir', false,
                    () => context.go(AppRoutes.convert))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String svgPath, String label, bool filled,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? Colors.white : Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(children: [
          SvgPicture.asset(
            svgPath,
            width: 22, height: 22,
            colorFilter: ColorFilter.mode(
              filled ? _primary : Colors.white,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: filled ? _primary : Colors.white,
            )),
        ]),
      ),
    );
  }

  Widget _buildRateBanner(WalletState walletState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(
            color: _success, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        const Text('Taux BTC/XOF',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8888AA),
          )),
        const Spacer(),
        Text('1 sat = ${walletState.rateXof.toStringAsFixed(2)} XOF',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _primary,
          )),
      ]),
    );
  }

  Widget _buildAutoConvert(bool enabled) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AutoConvertSettingsScreen(),
          ),
        ).then((_) => ref.read(autoConvertProvider.notifier).reload());
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: enabled ? _success.withOpacity(0.1) : _primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.sync,
              color: enabled ? _success : _primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Conversion automatique',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: enabled ? _success : const Color(0xFF0A0A2E))),
              const SizedBox(height: 2),
              Text(
                enabled
                  ? 'Activée — polling toutes les 30s'
                  : 'Désactivée → Toucher pour configurer',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8888AA))),
            ],
          )),
          Switch(
            value: enabled,
            onChanged: (v) => ref.read(autoConvertProvider.notifier).setEnabled(v),
            activeColor: _success,
          ),
        ]),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action,
      {VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: Color(0xFF8888AA),
          )),
        GestureDetector(
          onTap: onAction,
          child: Text(action,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _primary,
            )),
        ),
      ],
    );
  }

  Widget _buildOperators() {
    final operators = [
      {
        'name': 'MTN MoMo', 'short': 'MTN',
        'color': 0xFFFFCB05, 'text': 0xFF000000,
        'number': '+229 97 00 00 00', 'active': true
      },
      {
        'name': 'Moov Money', 'short': 'MOV',
        'color': 0xFF0052A5, 'text': 0xFFFFFFFF,
        'number': 'Ajouter', 'active': false
      },
      {
        'name': 'Celtiis', 'short': 'CEL',
        'color': 0xFFE30613, 'text': 0xFFFFFFFF,
        'number': 'Ajouter', 'active': false
      },
    ];

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: operators.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final op = operators[i];
          final isActive = op['active'] as bool;
          return Container(
            width: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive ? _primary : _border,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Color(op['color'] as int),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(op['short'] as String,
                    style: TextStyle(
                      color: Color(op['text'] as int),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    )),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(op['name'] as String,
                    style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                  Text(op['number'] as String,
                    style: const TextStyle(
                      fontSize: 9, color: Color(0xFF8888AA)),
                    overflow: TextOverflow.ellipsis),
                ],
              )),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return EmptyStateWidget(
      type: EmptyStateType.transactions,
      actionLabel: 'Recevoir des sats',
      onAction: () => context.go(AppRoutes.receive),
    );
  }

  // ── LND + Flash unified history ────────────────────────────────────────────

  List<Widget> _buildHistory({
    required List<dynamic> lndInvoices,
    required List<Map<String, dynamic>> lndPayments,
    required List<Map<String, dynamic>> flashTxs,
    required bool lndLoading,
  }) {
    final items = <HistoryItem>[];
    final rate = ref.read(walletProvider).rateXof;

    for (final inv in lndInvoices) {
      if (!inv.isPaid) continue;
      items.add(HistoryItem(
        type: TxType.received,
        date: inv.paidAt ?? inv.createdAt,
        amountSats: inv.amountSats,
        amountXof: (inv.amountSats * rate).round(),
        label: 'Lightning reçu',
        sublabel: (inv.memo != null && inv.memo!.isNotEmpty) ? inv.memo : null,
        memo: inv.memo,
        paymentHash: inv.paymentHash,
      ));
    }

    for (final pay in lndPayments) {
      if (pay['status'] != 'SUCCEEDED') continue;
      final valueSat = int.tryParse(pay['value_sat']?.toString() ?? '0') ?? 0;
      final feeSat = int.tryParse(pay['fee_sat']?.toString() ?? '0') ?? 0;
      final ts = int.tryParse(pay['creation_date']?.toString() ?? '0') ?? 0;
      final hash = pay['payment_hash'] as String?;
      final destAddr = hash != null ? _addressCache[hash] : null;
      items.add(HistoryItem(
        type: TxType.sent,
        date: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
        amountSats: valueSat,
        amountXof: (valueSat * rate).round(),
        label: 'Lightning envoyé',
        sublabel: destAddr ?? (feeSat > 0 ? 'Frais : $feeSat sats' : null),
        feeSats: feeSat,
        paymentHash: hash,
        destinationAddress: destAddr,
        paymentRequest: pay['payment_request'] as String?,
      ));
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    final lndItems = items.take(5).toList();

    final flashItems = flashTxs.take(3).map((tx) {
      final type = tx['type'] as String? ?? '';
      final isBuy = type == 'BUY_BITCOIN';
      final rawXof = (tx['amount_xof'] as String? ?? '0 XOF')
          .replaceAll(' XOF', '').replaceAll(',', '');
      final xof = double.tryParse(rawXof) ?? 0;
      final sats = (xof / rate).round();
      DateTime date;
      try { date = DateTime.parse(tx['created_at'] as String? ?? ''); }
      catch (_) { date = DateTime.now(); }
      return HistoryItem(
        type: TxType.converted,
        date: date,
        amountSats: sats,
        amountXof: xof.round(),
        label: isBuy ? 'Achat Bitcoin' : 'Vente Bitcoin',
        sublabel: tx['amount_xof'] as String?,
        status: tx['status'] as String?,
        reference: tx['reference'] as String?,
        operator: tx['mobile_money_operator'] as String?,
      );
    }).toList();

    final all = [...lndItems, ...flashItems];
    if (all.isEmpty) return [_buildEmptyTransactions()];
    return all.map(_buildDashboardItem).toList();
  }

  Widget _buildDashboardItem(HistoryItem item) {
    final IconData icon;
    final Color iconBg;
    final Color iconColor;
    final Color amountColor;
    final String sign;

    switch (item.type) {
      case TxType.received:
        icon = Icons.arrow_downward_rounded;
        iconBg = const Color(0xFFEEFFF6);
        iconColor = _success;
        amountColor = _success;
        sign = '+';
      case TxType.sent:
        icon = Icons.arrow_upward_rounded;
        iconBg = const Color(0xFFFFF0F0);
        iconColor = _error;
        amountColor = _error;
        sign = '-';
      case TxType.converted:
        icon = Icons.swap_horiz_rounded;
        iconBg = _primaryLight;
        iconColor = _primary;
        amountColor = const Color(0xFF0A0A2E);
        sign = '';
    }

    return GestureDetector(
      onTap: () => showTxDetail(context, item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label ?? '',
                style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
              if (item.sublabel != null) ...[
                const SizedBox(height: 2),
                Text(item.sublabel!,
                  style: const TextStyle(
                    fontSize: 11, color: Color(0xFF8888AA)),
                  overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 2),
              Text(_formatDate(item.date.toIso8601String()),
                style: const TextStyle(
                  fontSize: 11, color: Color(0xFF8888AA))),
              if (item.status != null && item.status != 'COMPLETED') ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.status == 'PENDING'
                        ? const Color(0xFFFFF8E1)
                        : const Color(0xFFEEFFF6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(item.status!,
                    style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: item.status == 'PENDING' ? Colors.orange : _success,
                    )),
                ),
              ],
            ],
          )),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$sign${_formatNum(item.amountSats)} sats',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: amountColor)),
              if (item.amountXof != null && item.amountXof! > 0) ...[
                const SizedBox(height: 2),
                Text('${_formatNum(item.amountXof!)} XOF',
                  style: const TextStyle(
                    fontSize: 10, color: Color(0xFF8888AA))),
              ],
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right,
                size: 14, color: Color(0xFFCCCCDD)),
            ],
          ),
        ]),
      ),
    );
  }

  String _formatNum(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) return 'Aujourd\'hui';
      if (diff.inDays == 1) return 'Hier';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _CurvesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path1 = Path();
    path1.moveTo(-20, size.height * 0.8);
    path1.quadraticBezierTo(
      size.width * 0.5, -size.height * 0.3,
      size.width + 20, size.height * 0.6);
    canvas.drawPath(path1, paint);

    final path2 = Path();
    path2.moveTo(-20, size.height * 0.9);
    path2.quadraticBezierTo(
      size.width * 0.6, -size.height * 0.1,
      size.width + 20, size.height * 0.4);
    canvas.drawPath(path2, paint);

    final path3 = Path();
    path3.moveTo(-20, size.height * 1.0);
    path3.quadraticBezierTo(
      size.width * 0.4, size.height * 0.1,
      size.width + 20, size.height * 0.2);
    canvas.drawPath(path3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}