import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Types partagés ────────────────────────────────────────────────────────────

enum TxType { received, sent, converted }

class HistoryItem {
  const HistoryItem({
    required this.type,
    required this.date,
    required this.amountSats,
    this.amountXof,
    this.label,
    this.sublabel,
    this.status,
    this.feeSats,
    this.paymentHash,
    this.reference,
    this.memo,
    this.operator,
    this.destinationAddress,
    this.paymentRequest,
  });

  final TxType type;
  final DateTime date;
  final int amountSats;
  final int? amountXof;
  final String? label;
  final String? sublabel;
  final String? status;
  final int? feeSats;
  final String? paymentHash;
  final String? reference;
  final String? memo;
  final String? operator;
  final String? destinationAddress;
  final String? paymentRequest; // BOLT11 invoice (fallback si pas d'adresse)
}

// ── Fonction utilitaire pour ouvrir le sheet ─────────────────────────────────

void showTxDetail(BuildContext context, HistoryItem item) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TxDetailSheet(item: item),
  );
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────

class TxDetailSheet extends StatelessWidget {
  const TxDetailSheet({super.key, required this.item});

  final HistoryItem item;

  static const Color _border = Color(0xFFE8E8F4);
  static const Color _primary = Color(0xFF1C28F0);
  static const Color _success = Color(0xFF00B96B);
  static const Color _error = Color(0xFFE83333);

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color iconBg;
    final Color iconColor;
    final Color amountColor;
    final String sign;
    final String typeLabel;

    switch (item.type) {
      case TxType.received:
        icon = Icons.arrow_downward_rounded;
        iconBg = const Color(0xFFEEFFF6);
        iconColor = _success;
        amountColor = _success;
        sign = '+';
        typeLabel = 'Paiement reçu';
      case TxType.sent:
        icon = Icons.arrow_upward_rounded;
        iconBg = const Color(0xFFFFF0F0);
        iconColor = _error;
        amountColor = _error;
        sign = '-';
        typeLabel = 'Paiement envoyé';
      case TxType.converted:
        icon = Icons.swap_horiz_rounded;
        iconBg = const Color(0xFFFFF8E1);
        iconColor = const Color(0xFFFFA000);
        amountColor = const Color(0xFF0A0A2E);
        sign = '';
        typeLabel = item.label ?? 'Conversion';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDEE),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon + type label
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            typeLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8888AA),
            ),
          ),
          const SizedBox(height: 6),

          // Amount
          Text(
            '$sign${_fNum(item.amountSats)} sats',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: amountColor,
              letterSpacing: -0.5,
            ),
          ),
          if (item.amountXof != null && item.amountXof! > 0) ...[
            const SizedBox(height: 4),
            Text(
              '≈ ${_fNum(item.amountXof!)} XOF',
              style: const TextStyle(fontSize: 14, color: Color(0xFF8888AA)),
            ),
          ],
          const SizedBox(height: 20),

          // Status pill
          if (item.status != null) ...[
            _statusPill(item.status!),
            const SizedBox(height: 16),
          ],

          // Detail rows
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                _row('Date', _fDateTime(item.date)),
                if (item.destinationAddress != null)
                  _copyRow(context, 'Destinataire', item.destinationAddress!)
                else if (item.type == TxType.sent && item.paymentRequest != null)
                  _copyRow(context, 'Invoice', item.paymentRequest!),
                if (item.memo != null && item.memo!.isNotEmpty)
                  _row('Note', item.memo!),
                if (item.feeSats != null && item.feeSats! > 0)
                  _row('Frais réseau', '${_fNum(item.feeSats!)} sats'),
                if (item.operator != null)
                  _row('Opérateur', item.operator!),
                if (item.paymentHash != null)
                  _copyRow(context, 'Hash', item.paymentHash!),
                if (item.reference != null)
                  _copyRow(context, 'Référence', item.reference!),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5F5FA),
                foregroundColor: const Color(0xFF0A0A2E),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
              child: const Text('Fermer'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static String _fNum(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  static String _fTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _fDateTime(DateTime d) {
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun',
                    'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${d.day} ${months[d.month - 1]} ${d.year} à ${_fTime(d)}';
  }

  Widget _statusPill(String status) {
    final isPending = status == 'PENDING';
    final isCompleted = status == 'COMPLETED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isPending
            ? const Color(0xFFFFF8E1)
            : isCompleted
                ? const Color(0xFFEEFFF6)
                : const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPending ? 'En attente' : isCompleted ? 'Complété' : status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isPending
              ? const Color(0xFFFFA000)
              : isCompleted
                  ? _success
                  : _error,
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEF8))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8888AA))),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A0A2E),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _copyRow(BuildContext context, String label, String value) {
    final short = value.length > 20
        ? '${value.substring(0, 10)}…${value.substring(value.length - 6)}'
        : value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEF8))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8888AA))),
          ),
          Expanded(
            child: Text(
              short,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A0A2E),
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('$label copié'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: _primary,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ));
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.copy_rounded, size: 14, color: _primary),
            ),
          ),
        ],
      ),
    );
  }
}
