import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/transaction.dart';
import '../../../shared/services/lnd_service.dart';

// ─────────────────────────────────────────
// Confirmation Réception Lightning
// ─────────────────────────────────────────
class ReceiveConfirmScreen extends ConsumerWidget {
  final Transaction transaction;
  final String? senderName;

  const ReceiveConfirmScreen({
    super.key,
    required this.transaction,
    this.senderName,
  });

  static const Color _primary = Color(0xFF1C28F0);
  static const Color _primaryLight = Color(0xFFEEF0FF);
  static const Color _success = Color(0xFF00B96B);
  static const Color _successLight = Color(0xFFEEFFF6);
  static const Color _border = Color(0xFFE8E8F4);
  static const Color _textSecondary = Color(0xFF8888AA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lndBalance = ref.watch(lndBalanceProvider);
    final senderInitials = senderName != null && senderName!.isNotEmpty
        ? senderName!.substring(0, 1).toUpperCase()
        : '?';
    final dateFormatted = DateFormat('dd MMM yyyy, HH:mm', 'fr_FR')
        .format(transaction.createdAt);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.dashboard),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(Icons.close, size: 18,
                      color: Color(0xFF0A0A2E)),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: _successLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _success.withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(Icons.flash_on, color: _success, size: 44),
              ),
              const SizedBox(height: 20),

              const Text('Paiement reçu !',
                style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800,
                  color: Color(0xFF0A0A2E))),
              const SizedBox(height: 8),
              const Text('Vous venez de recevoir des sats via Lightning',
                style: TextStyle(fontSize: 14, color: _textSecondary),
                textAlign: TextAlign.center),
              const SizedBox(height: 24),

              // Expéditeur
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3498DB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(senderInitials,
                        style: const TextStyle(color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w700))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(senderName ?? 'Expéditeur',
                          style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(transaction.senderAddress ?? '',
                          style: const TextStyle(
                            fontSize: 12, color: _textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.flash_on, color: _primary, size: 20),
                ]),
              ),
              const SizedBox(height: 16),

              // Montant
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x261C28F0)),
                ),
                child: Column(children: [
                  Text('+${transaction.formattedAmountSats} sats',
                    style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.w900,
                      color: _success)),
                  const SizedBox(height: 4),
                  Text('≈ ${transaction.formattedAmountXof} XOF',
                    style: const TextStyle(fontSize: 16, color: _textSecondary)),
                  const SizedBox(height: 4),
                  Text('au taux de 1 sat = ${transaction.exchangeRate.toStringAsFixed(2)} XOF',
                    style: const TextStyle(fontSize: 11, color: _textSecondary)),
                ]),
              ),
              const SizedBox(height: 16),

              // Détails
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: Column(children: [
                  _detailRow('Date', dateFormatted),
                  const SizedBox(height: 10),
                  _detailRow('Type', '⚡ Lightning', valueColor: _primary),
                  const SizedBox(height: 10),
                  _detailRow('Frais réseau', '0 sats', valueColor: _success),
                  const SizedBox(height: 10),
                  if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                    _detailRow('Note', '"${transaction.note}"'),
                    const SizedBox(height: 10),
                  ],
                  _detailRow('Statut', transaction.statusLabel,
                    valueColor: _success),
                  const SizedBox(height: 10),
                  _buildTxIdRow(transaction.lightningInvoice ?? transaction.id),
                ]),
              ),
              const SizedBox(height: 16),

              // Solde restant
              _buildBalanceRow(lndBalance, transaction.exchangeRate),
              const SizedBox(height: 16),

              _buildStatusTracker(step: 2),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Retour à l\'accueil',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: Colors.white)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.convert),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: _primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Convertir maintenant',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTxIdRow(String txId) {
    final display = txId.length > 24
        ? '${txId.substring(0, 12)}...${txId.substring(txId.length - 8)}'
        : txId;
    return GestureDetector(
      onTap: () => Clipboard.setData(ClipboardData(text: txId)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ID TRANSACTION',
                  style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    letterSpacing: 1.5, color: _textSecondary)),
                const SizedBox(height: 2),
                Text(display,
                  style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    fontFamily: 'monospace')),
              ],
            ),
          ),
          const Icon(Icons.copy, size: 16, color: _textSecondary),
        ]),
      ),
    );
  }

  Widget _buildBalanceRow(int lndBalance, double rate) {
    final xof = (lndBalance * rate).toInt();
    final fmtSats = lndBalance.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    final fmtXof = xof.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x261C28F0)),
      ),
      child: Row(children: [
        const Text('Solde restant',
          style: TextStyle(fontSize: 13, color: _textSecondary)),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$fmtSats sats',
              style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: _primary)),
            Text('≈ $fmtXof XOF',
              style: const TextStyle(fontSize: 11, color: _textSecondary)),
          ],
        ),
      ]),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, color: _textSecondary)),
      const Spacer(),
      Text(value,
        style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: valueColor ?? const Color(0xFF0A0A2E))),
    ]);
  }

  Widget _buildStatusTracker({required int step}) {
    final steps = ['Initié', 'Confirmé', 'Reçu'];
    return Row(children: List.generate(3, (i) {
      final isDone = i <= step;
      return Expanded(
        child: Row(children: [
          Expanded(
            child: Column(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: isDone ? _success : const Color(0xFFE8E8F4),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check,
                  color: isDone ? Colors.white : _textSecondary, size: 14),
              ),
              const SizedBox(height: 4),
              Text(steps[i],
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: isDone ? _success : _textSecondary)),
            ]),
          ),
          if (i < 2)
            Expanded(
              child: Container(
                height: 2,
                color: i < step ? _success : const Color(0xFFE8E8F4),
                margin: const EdgeInsets.only(bottom: 20),
              ),
            ),
        ]),
      );
    }));
  }
}

// ─────────────────────────────────────────
// Confirmation Envoi Lightning
// ─────────────────────────────────────────
class SendConfirmScreen extends ConsumerWidget {
  final Transaction transaction;
  final String? receiverName;

  const SendConfirmScreen({
    super.key,
    required this.transaction,
    this.receiverName,
  });

  static const Color _primary = Color(0xFF1C28F0);
  static const Color _primaryLight = Color(0xFFEEF0FF);
  static const Color _success = Color(0xFF00B96B);
  static const Color _error = Color(0xFFE83333);
  static const Color _border = Color(0xFFE8E8F4);
  static const Color _textSecondary = Color(0xFF8888AA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lndBalance = ref.watch(lndBalanceProvider);
    final receiverInitials = receiverName != null && receiverName!.isNotEmpty
        ? receiverName!.substring(0, 2).toUpperCase()
        : '??';
    final dateFormatted = DateFormat('dd MMM yyyy, HH:mm', 'fr_FR')
        .format(transaction.createdAt);
    final txId = transaction.lightningInvoice ?? transaction.id;
    final txIdDisplay = txId.length > 24
        ? '${txId.substring(0, 12)}...${txId.substring(txId.length - 8)}'
        : txId;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.dashboard),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(Icons.close, size: 18,
                      color: Color(0xFF0A0A2E)),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: _primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _primary.withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(Icons.arrow_upward,
                  color: _primary, size: 40),
              ),
              const SizedBox(height: 20),

              const Text('Paiement envoyé !',
                style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800,
                  color: Color(0xFF0A0A2E))),
              const SizedBox(height: 8),
              const Text('Votre paiement Lightning a été envoyé avec succès',
                style: TextStyle(fontSize: 14, color: _textSecondary),
                textAlign: TextAlign.center),
              const SizedBox(height: 24),

              // Destinataire
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B59B6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(receiverInitials,
                        style: const TextStyle(color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w700))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(receiverName ?? 'Destinataire',
                          style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(
                          (transaction.receiverAddress ?? '').length > 30
                            ? '${(transaction.receiverAddress ?? '').substring(0, 28)}...'
                            : transaction.receiverAddress ?? '',
                          style: const TextStyle(
                            fontSize: 12, color: _textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.flash_on, color: _primary, size: 20),
                ]),
              ),
              const SizedBox(height: 16),

              // Montant
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _error.withValues(alpha: 0.15)),
                ),
                child: Column(children: [
                  Text('-${transaction.formattedAmountSats} sats',
                    style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.w900,
                      color: _error)),
                  const SizedBox(height: 4),
                  Text('≈ ${transaction.formattedAmountXof} XOF',
                    style: const TextStyle(fontSize: 16, color: _textSecondary)),
                  const SizedBox(height: 4),
                  Text('au taux de 1 sat = ${transaction.exchangeRate.toStringAsFixed(2)} XOF',
                    style: const TextStyle(fontSize: 11, color: _textSecondary)),
                ]),
              ),
              const SizedBox(height: 16),

              // Détails
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: Column(children: [
                  _detailRow('Date', dateFormatted),
                  const SizedBox(height: 10),
                  _detailRow('Type', '⚡ Lightning', valueColor: _primary),
                  const SizedBox(height: 10),
                  _detailRow('Frais réseau', '≈ 1–2 sats'),
                  if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _detailRow('Note', '"${transaction.note}"'),
                  ],
                  const SizedBox(height: 10),
                  _detailRow('Statut', transaction.statusLabel,
                    valueColor: _success),
                  const SizedBox(height: 10),
                  // ID transaction copiable
                  GestureDetector(
                    onTap: () => Clipboard.setData(ClipboardData(text: txId)),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ID TRANSACTION',
                                style: TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5, color: _textSecondary)),
                              const SizedBox(height: 2),
                              Text(txIdDisplay,
                                style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace')),
                            ],
                          ),
                        ),
                        const Icon(Icons.copy, size: 16, color: _textSecondary),
                      ]),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // Solde restant (live depuis LND)
              _buildBalanceRow(lndBalance, transaction.exchangeRate),
              const SizedBox(height: 16),

              _buildStatusTracker(),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Retour à l\'accueil',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: Colors.white)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.send),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: _primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Envoyer à nouveau',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceRow(int lndBalance, double rate) {
    final xof = (lndBalance * rate).toInt();
    final fmtSats = lndBalance.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    final fmtXof = xof.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x261C28F0)),
      ),
      child: Row(children: [
        const Text('Solde restant',
          style: TextStyle(fontSize: 13, color: _textSecondary)),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$fmtSats sats',
              style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: _primary)),
            Text('≈ $fmtXof XOF',
              style: const TextStyle(fontSize: 11, color: _textSecondary)),
          ],
        ),
      ]),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, color: _textSecondary)),
      const Spacer(),
      Flexible(
        child: Text(value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: valueColor ?? const Color(0xFF0A0A2E))),
      ),
    ]);
  }

  Widget _buildStatusTracker() {
    final steps = ['Initié', 'Confirmé', 'Reçu'];
    return Row(children: List.generate(3, (i) {
      return Expanded(
        child: Row(children: [
          Expanded(
            child: Column(children: [
              Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(
                  color: _success, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
              const SizedBox(height: 4),
              Text(steps[i],
                style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: _success)),
            ]),
          ),
          if (i < 2)
            const Expanded(
              child: SizedBox(
                height: 2,
                child: ColoredBox(color: _success),
              ),
            ),
        ]),
      );
    }));
  }
}

// ─────────────────────────────────────────
// Confirmation Conversion
// ─────────────────────────────────────────
class ConvertConfirmScreen extends ConsumerWidget {
  final bool isSell;
  final Transaction? transaction;

  const ConvertConfirmScreen({
    super.key,
    this.isSell = true,
    this.transaction,
  });

  static const Color _primary = Color(0xFF1C28F0);
  static const Color _primaryLight = Color(0xFFEEF0FF);
  static const Color _success = Color(0xFF00B96B);
  static const Color _successLight = Color(0xFFEEFFF6);
  static const Color _border = Color(0xFFE8E8F4);
  static const Color _textSecondary = Color(0xFF8888AA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lndBalance = ref.watch(lndBalanceProvider);
    final tx = transaction;

    // Calculs depuis la transaction réelle
    final amountSats = tx?.amountSats ?? 0;
    final amountXof  = tx?.amountXof ?? 0;
    final rate       = tx?.exchangeRate ?? 3.84;
    final feesXof    = (amountXof * 0.005).toInt();
    final feesSats   = (amountSats * 0.005).toInt();
    final youReceive = isSell ? amountXof - feesXof : amountSats - feesSats;
    final operator   = tx?.mobileMoneyOperator ?? 'Mobile Money';
    final opNumber   = tx?.mobileMoneyNumber ?? '';
    final txId       = tx?.id ?? '';

    String fmtSats(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.dashboard),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(Icons.close, size: 18,
                      color: Color(0xFF0A0A2E)),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: isSell ? _successLight : _primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isSell ? _success : _primary).withValues(alpha: 0.3),
                    width: 2),
                ),
                child: Icon(
                  isSell ? Icons.check : Icons.flash_on,
                  color: isSell ? _success : _primary,
                  size: 44),
              ),
              const SizedBox(height: 20),

              Text(isSell ? 'Conversion réussie !' : 'Achat réussi !',
                style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800,
                  color: Color(0xFF0A0A2E))),
              const SizedBox(height: 8),
              Text(
                isSell
                  ? 'Vos fonds sont en route vers $operator'
                  : 'Les sats sont dans votre wallet Flash',
                style: const TextStyle(fontSize: 14, color: _textSecondary),
                textAlign: TextAlign.center),
              const SizedBox(height: 24),

              // Récapitulatif
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSell ? _primaryLight : _successLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isSell ? _primary : _success).withValues(alpha: 0.15)),
                ),
                child: Column(children: [
                  _summaryRow(
                    isSell ? 'Vous avez vendu' : 'Vous avez payé',
                    isSell
                      ? '${fmtSats(amountSats)} sats'
                      : '${fmtSats(amountXof)} XOF',
                    valueColor: isSell ? _primary : _success),
                  if (!isSell) ...[
                    const SizedBox(height: 10),
                    _summaryRow('Via', operator),
                  ],
                  const SizedBox(height: 10),
                  _summaryRow('Taux appliqué',
                    '1 sat = ${rate.toStringAsFixed(2)} XOF'),
                  const SizedBox(height: 10),
                  _summaryRow('Frais Flash (0,5%)',
                    isSell
                      ? '${fmtSats(feesXof)} XOF'
                      : '${fmtSats(feesSats)} sats'),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1)),
                  Row(children: [
                    const Text('Vous recevez',
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: Color(0xFF0A0A2E))),
                    const Spacer(),
                    Text(
                      isSell
                        ? '${fmtSats(youReceive)} XOF'
                        : '${fmtSats(youReceive)} sats',
                      style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900,
                        color: isSell ? _success : _primary)),
                  ]),
                  const SizedBox(height: 10),
                  if (!isSell)
                    _summaryRow('Nouveau solde', '${fmtSats(lndBalance)} sats'),
                  if (isSell) ...[
                    _summaryRow('Opérateur',
                      opNumber.isNotEmpty ? '$operator — $opNumber' : operator),
                    const SizedBox(height: 10),
                    _summaryRow('Délai estimé', '⏱ moins de 2 minutes'),
                  ],
                ]),
              ),
              const SizedBox(height: 16),

              // ID Transaction copiable
              if (txId.isNotEmpty)
                GestureDetector(
                  onTap: () => Clipboard.setData(ClipboardData(text: txId)),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ID TRANSACTION',
                              style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w700,
                                letterSpacing: 1.5, color: _textSecondary)),
                            const SizedBox(height: 2),
                            Text(txId,
                              style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const Icon(Icons.copy, size: 16, color: _textSecondary),
                    ]),
                  ),
                ),
              const SizedBox(height: 16),

              _buildStatusTracker(isSell: isSell),
              const SizedBox(height: 16),

              if (isSell)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _success,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(children: [
                    Icon(Icons.chat, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vous recevrez une confirmation WhatsApp',
                        style: TextStyle(color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Retour à l\'accueil',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: Colors.white)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go(
                  isSell ? AppRoutes.convert : AppRoutes.send),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: _primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(isSell ? 'Nouvelle conversion' : 'Envoyer ces sats',
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, color: _textSecondary)),
      const Spacer(),
      Flexible(
        child: Text(value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: valueColor ?? const Color(0xFF0A0A2E))),
      ),
    ]);
  }

  Widget _buildStatusTracker({required bool isSell}) {
    final steps = ['Initié', 'En cours', 'Reçu'];
    return Row(children: List.generate(3, (i) {
      final isDone = isSell ? i == 0 : true;
      final isCurrent = isSell && i == 1;
      return Expanded(
        child: Row(children: [
          Expanded(
            child: Column(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: isDone ? _success : isCurrent
                    ? _primary : const Color(0xFFE8E8F4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDone ? Icons.check
                    : isCurrent ? Icons.sync : Icons.access_time,
                  color: isDone || isCurrent ? Colors.white : _textSecondary,
                  size: 14),
              ),
              const SizedBox(height: 4),
              Text(steps[i],
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: isDone ? _success
                    : isCurrent ? _primary : _textSecondary)),
            ]),
          ),
          if (i < 2)
            Expanded(
              child: Container(
                height: 2,
                color: i == 0 ? _success : const Color(0xFFE8E8F4),
                margin: const EdgeInsets.only(bottom: 20),
              ),
            ),
        ]),
      );
    }));
  }
}
