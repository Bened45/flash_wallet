import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/lnd_service.dart';
import '../../../shared/services/payment_address_cache.dart';
import '../../../shared/services/wallet_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/skeleton_widgets.dart';
import '../../../shared/widgets/tx_detail_sheet.dart';

// ── Filter enum ──────────────────────────────────────────────────────────────

enum _Filter { all, received, sent, converted }

// ── Screen ───────────────────────────────────────────────────────────────────

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF1C28F0);
  static const Color _success = Color(0xFF00B96B);
  static const Color _error = Color(0xFFE83333);
  static const Color _border = Color(0xFFE8E8F4);

  _Filter _filter = _Filter.all;
  final _searchCtrl = TextEditingController();
  String _query = '';
  Map<String, String> _addressCache = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF1C28F0),
      statusBarIconBrightness: Brightness.light,
    ));
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase());
    });
    _loadAddressCache();
  }

  Future<void> _loadAddressCache() async {
    final cache = await PaymentAddressCache.loadAll();
    if (mounted) setState(() => _addressCache = cache);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data merging ─────────────────────────────────────────────────────────────

  List<HistoryItem> _buildItems({
    required List<dynamic> invoices,
    required List<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> flashTxs,
    required double rate,
    required Map<String, String> addressCache,
  }) {
    final items = <HistoryItem>[];

    for (final inv in invoices) {
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

    for (final pay in payments) {
      if (pay['status'] != 'SUCCEEDED') continue;
      final valueSat = int.tryParse(pay['value_sat']?.toString() ?? '0') ?? 0;
      final feeSat = int.tryParse(pay['fee_sat']?.toString() ?? '0') ?? 0;
      final ts = int.tryParse(pay['creation_date']?.toString() ?? '0') ?? 0;
      final hash = pay['payment_hash'] as String?;
      final destAddr = hash != null ? addressCache[hash] : null;
      items.add(HistoryItem(
        type: TxType.sent,
        date: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
        amountSats: valueSat,
        amountXof: (valueSat * rate).round(),
        label: 'Lightning envoyé',
        sublabel: destAddr ?? (feeSat > 0 ? 'Frais : $feeSat sats' : null),
        feeSats: feeSat,
        paymentHash: hash,
        memo: pay['description'] as String?,
        destinationAddress: destAddr,
        paymentRequest: pay['payment_request'] as String?,
      ));
    }

    for (final tx in flashTxs) {
      final type = tx['type'] as String? ?? '';
      final rawXof = (tx['amount_xof'] as String? ?? '0 XOF')
          .replaceAll(' XOF', '')
          .replaceAll(',', '');
      final xof = double.tryParse(rawXof) ?? 0;
      final sats = (xof / rate).round();
      final ts = tx['created_at'] as String? ?? '';
      DateTime date;
      try {
        date = DateTime.parse(ts);
      } catch (_) {
        date = DateTime.now();
      }
      items.add(HistoryItem(
        type: TxType.converted,
        date: date,
        amountSats: sats,
        amountXof: xof.round(),
        label: type == 'BUY_BITCOIN' ? 'Achat Bitcoin' : 'Vente Bitcoin',
        sublabel: tx['amount_xof'] as String?,
        status: tx['status'] as String?,
        reference: tx['reference'] as String?,
        operator: tx['mobile_money_operator'] as String?,
        memo: tx['amount_xof'] as String?,
      ));
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  // ── Filtering ────────────────────────────────────────────────────────────────

  List<HistoryItem> _applyFilter(List<HistoryItem> items) {
    return items.where((item) {
      final matchFilter = switch (_filter) {
        _Filter.all => true,
        _Filter.received => item.type == TxType.received,
        _Filter.sent => item.type == TxType.sent,
        _Filter.converted => item.type == TxType.converted,
      };
      if (!matchFilter) return false;
      if (_query.isEmpty) return true;
      return (item.label?.toLowerCase().contains(_query) ?? false) ||
          (item.sublabel?.toLowerCase().contains(_query) ?? false) ||
          (item.memo?.toLowerCase().contains(_query) ?? false) ||
          (item.paymentHash?.toLowerCase().contains(_query) ?? false) ||
          (item.reference?.toLowerCase().contains(_query) ?? false);
    }).toList();
  }

  // ── Date grouping ─────────────────────────────────────────────────────────────

  String _dateGroup(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDay = DateTime(d.year, d.month, d.day);
    if (itemDay == today) return "Aujourd'hui";
    if (itemDay == yesterday) return 'Hier';
    if (today.difference(itemDay).inDays < 7) {
      const days = ['', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
      return days[itemDay.weekday];
    }
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // ── Formatting ────────────────────────────────────────────────────────────────

  String _fNum(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  String _fTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // ── Detail bottom sheet ───────────────────────────────────────────────────────

  void _showDetail(HistoryItem item) => showTxDetail(context, item);

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lndState = ref.watch(lndProvider);
    final lndInvoices = ref.watch(lndInvoicesProvider);
    final lndPayments = ref.watch(lndPaymentsProvider);
    final walletState = ref.watch(walletProvider);

    final isLoading =
        lndState.isLoading && lndInvoices.isEmpty && lndPayments.isEmpty;

    final all = _buildItems(
      invoices: lndInvoices,
      payments: lndPayments,
      flashTxs: walletState.transactions,
      rate: walletState.rateXof,
      addressCache: _addressCache,
    );
    final filtered = _applyFilter(all);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: Column(
        children: [
          _buildHeader(context, all.length),
          _buildSearchBar(),
          _buildFilterTabs(all),
          Expanded(
            child: isLoading
                ? _buildSkeleton()
                : filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        color: _primary,
                        onRefresh: () async {
                          ref.read(lndProvider.notifier).refresh();
                          await ref.read(walletProvider.notifier).loadAll();
                          await _loadAddressCache();
                        },
                        child: _buildList(filtered),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, int total) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Historique',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (total > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$total txs',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(fontSize: 14, color: Color(0xFF0A0A2E)),
        decoration: InputDecoration(
          hintText: 'Rechercher une transaction...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8888AA)),
          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF8888AA)),
          suffixIcon: _query.isNotEmpty
              ? GestureDetector(
                  onTap: () => _searchCtrl.clear(),
                  child: const Icon(Icons.close, size: 18, color: Color(0xFF8888AA)),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF5F5FA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── Filter tabs ───────────────────────────────────────────────────────────────

  Widget _buildFilterTabs(List<HistoryItem> all) {
    int countFor(_Filter f) => switch (f) {
          _Filter.all => all.length,
          _Filter.received => all.where((i) => i.type == TxType.received).length,
          _Filter.sent => all.where((i) => i.type == TxType.sent).length,
          _Filter.converted => all.where((i) => i.type == TxType.converted).length,
        };

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(_Filter.all, 'Tout', countFor(_Filter.all)),
            const SizedBox(width: 8),
            _filterChip(_Filter.received, 'Reçu', countFor(_Filter.received), color: _success),
            const SizedBox(width: 8),
            _filterChip(_Filter.sent, 'Envoyé', countFor(_Filter.sent), color: _error),
            const SizedBox(width: 8),
            _filterChip(_Filter.converted, 'Converti', countFor(_Filter.converted),
                color: const Color(0xFFFFA000)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(_Filter f, String label, int count, {Color? color}) {
    final isActive = _filter == f;
    final activeColor = color ?? _primary;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? activeColor : const Color(0xFFF5F5FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor : _border,
            width: 1.5,
          ),
        ),
        child: Row(children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : const Color(0xFF8888AA),
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.25)
                    : activeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isActive ? Colors.white : activeColor,
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ── List with date groups ─────────────────────────────────────────────────────

  Widget _buildList(List<HistoryItem> items) {
    final groups = <String, List<HistoryItem>>{};
    for (final item in items) {
      final g = _dateGroup(item.date);
      groups.putIfAbsent(g, () => []).add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: groups.length,
      itemBuilder: (context, groupIdx) {
        final groupLabel = groups.keys.elementAt(groupIdx);
        final groupItems = groups[groupLabel]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dateHeader(groupLabel),
            const SizedBox(height: 8),
            ...groupItems.map(_buildItem),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _dateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Color(0xFF8888AA),
        ),
      ),
    );
  }

  Widget _buildItem(HistoryItem item) {
    IconData icon;
    Color iconBg;
    Color iconColor;
    Color amountColor;
    String sign;

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
        iconBg = const Color(0xFFFFF8E1);
        iconColor = const Color(0xFFFFA000);
        amountColor = const Color(0xFF0A0A2E);
        sign = '';
    }

    return GestureDetector(
      onTap: () => _showDetail(item),
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A0A2E),
                  ),
                ),
                if (item.sublabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.sublabel!,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF8888AA)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Row(children: [
                  Text(
                    _fTime(item.date),
                    style: const TextStyle(fontSize: 10, color: Color(0xFFBBBBCC)),
                  ),
                  if (item.status != null && item.status != 'COMPLETED') ...[
                    const SizedBox(width: 6),
                    _statusBadge(item.status!),
                  ],
                ]),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${_fNum(item.amountSats)} sats',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
              if (item.amountXof != null && item.amountXof! > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '${_fNum(item.amountXof!)} XOF',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF8888AA)),
                ),
              ],
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right, size: 14, color: Color(0xFFCCCCDD)),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isCompleted = status == 'COMPLETED';
    final isPending = status == 'PENDING';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isPending
            ? const Color(0xFFFFF8E1)
            : isCompleted
                ? const Color(0xFFEEFFF6)
                : const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: isPending
              ? const Color(0xFFFFA000)
              : isCompleted
                  ? _success
                  : _error,
        ),
      ),
    );
  }

  // ── Skeleton ──────────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: 8,
      itemBuilder: (_, __) => const TransactionItemSkeleton(),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    if (_query.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5FA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_off_rounded,
                    size: 32, color: Color(0xFF8888AA)),
              ),
              const SizedBox(height: 16),
              Text(
                'Aucun résultat pour\n"$_query"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A0A2E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Essayez un autre terme de recherche.',
                style: TextStyle(fontSize: 12, color: Color(0xFF8888AA)),
              ),
            ],
          ),
        ),
      );
    }

    final emptyTitle = switch (_filter) {
      _Filter.received => 'Aucun paiement reçu',
      _Filter.sent => 'Aucun paiement envoyé',
      _Filter.converted => 'Aucune conversion',
      _Filter.all => 'Aucune transaction',
    };

    final emptySubtitle = switch (_filter) {
      _Filter.received => 'Partagez votre adresse Lightning pour recevoir des sats.',
      _Filter.sent => 'Vos paiements envoyés apparaîtront ici.',
      _Filter.converted => 'Vos conversions BTC ↔ XOF apparaîtront ici.',
      _Filter.all => 'Vos paiements Lightning et conversions\napparaîtront ici.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyStateWidget(
          type: EmptyStateType.transactions,
          title: emptyTitle,
          subtitle: emptySubtitle,
        ),
      ),
    );
  }
}
