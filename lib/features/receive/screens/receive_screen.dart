import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/services/auth_provider.dart';
import '../../../shared/services/lnd_service.dart';
import '../../../shared/services/wallet_provider.dart';

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  static const Color _primary = Color(0xFF1C28F0);
  static const Color _primaryLight = Color(0xFFEEF0FF);
  static const Color _border = Color(0xFFE8E8F4);
  static const Color _textSecondary = Color(0xFF8888AA);
  static const Color _success = Color(0xFF00B96B);

  final _amountController = TextEditingController();
  bool _copied = false;
  String? _currentInvoice;
  int? _currentAmountSats;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final walletState = ref.watch(walletProvider);
    final lndState = ref.watch(lndProvider);
    // Polar dev node address — shown alongside the user's Flash address.
    final lightningAddress = authState.lightningAddress;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0A0A2E)),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
        title: const Text('Recevoir',
            style: TextStyle(
              color: Color(0xFF0A0A2E),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            )),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Info Lightning
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x261C28F0)),
              ),
              child: Row(children: [
                const Icon(Icons.flash_on, color: _primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    walletState.error != null
                        ? '⚠ ${walletState.error}'
                        : 'Recevez des sats instantanément via Lightning Network',
                    style: TextStyle(
                      fontSize: 12,
                      color: walletState.error != null ? Colors.red : _primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // Invoice créée ou adresse Lightning
            if (_currentInvoice != null && _currentAmountSats != null)
              _buildInvoiceCard(lightningAddress)
            else
              _buildAddressCard(lightningAddress),
            const SizedBox(height: 20),

            // Boutons Copier / Partager
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _copyAddress(_currentInvoice ?? lightningAddress),
                  icon: Icon(
                    _copied ? Icons.check : Icons.copy,
                    size: 16),
                  label: Text(_copied ? 'Copié !' : 'Copier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _copied ? _success : _primary,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _share(_currentInvoice ?? lightningAddress),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Partager'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: const BorderSide(color: _primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // Demander un montant précis → Créer une invoice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x261C28F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Demander un montant précis',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A0A2E),
                    )),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _textSecondary.withOpacity(0.3),
                      ),
                      suffixText: 'sats',
                      suffixStyle: const TextStyle(
                        fontSize: 16,
                        color: _textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                  Text(
                    '≈ ${_toXof()} XOF',
                    style: const TextStyle(
                      fontSize: 12, color: _textSecondary)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _amountController.text.isNotEmpty &&
                              !lndState.isLoading
                          ? () => _createInvoice()
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: lndState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Créer une invoice',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              )),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(children: [
                const Icon(Icons.flash_on, color: _primary, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Les paiements Lightning arrivent en quelques secondes',
                    style: TextStyle(
                      fontSize: 12, color: _textSecondary)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard(String lightningAddress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // QR code de l'adresse Lightning principale
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: lightningAddress.isEmpty ? 'flash@bitcoinflash.xyz' : lightningAddress,
                version: QrVersions.auto,
                size: 160,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF1C28F0),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0A0A2E),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Adresse Flash (compte utilisateur)
          GestureDetector(
            onTap: () => _copyAddress(lightningAddress),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('VOTRE ADRESSE FLASH',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      )),
                    const SizedBox(height: 4),
                    Text(
                      lightningAddress.isEmpty ? 'Chargement...' : lightningAddress,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      )),
                  ],
                ),
              ),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _copied ? Icons.check : Icons.copy,
                  color: Colors.white, size: 16),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(String lightningAddress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x261C28F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('INVOICE CRÉÉE',
                style: TextStyle(
                  color: _primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                )),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _currentInvoice = null;
                    _currentAmountSats = null;
                    _amountController.clear();
                  });
                },
                icon: const Icon(Icons.close, size: 16, color: _textSecondary),
                label: const Text('Fermer',
                  style: TextStyle(color: _textSecondary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: _primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_currentAmountSats} sats',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A0A2E),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '≈ ${(_currentAmountSats! * 3.84).toStringAsFixed(0)} XOF',
                style: const TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // QR Code de l'invoice
          Center(
            child: QrImageView(
              data: _currentInvoice!,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF1C28F0),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0A0A2E),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('Scanner pour payer',
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              )),
          ),
          const SizedBox(height: 12),
          // Invoice text (truncated)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Text(
              _currentInvoice!,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: _textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createInvoice() async {
    final amountSats = int.tryParse(_amountController.text);
    if (amountSats == null || amountSats <= 0) return;

    final authState = ref.read(authProvider);
    final memo = 'Paiement Flash — ${authState.lightningAddress.isNotEmpty ? authState.lightningAddress : 'benedoffice1@bitcoinflash.xyz'}';

    // Crée la vraie invoice BOLT11 via le nœud LND Alice (Polar).
    final pr = await ref.read(lndProvider.notifier).createInvoice(amountSats, memo);

    if (pr != null && mounted) {
      setState(() {
        _currentInvoice = pr;
        _currentAmountSats = amountSats;
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Impossible de créer l\'invoice LND'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _copyAddress(String address) {
    if (address.isEmpty) return;
    Clipboard.setData(ClipboardData(text: address));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✓ Copié !'),
        backgroundColor: _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _share(String address) {
    if (address.isEmpty) return;
    Share.share('Payez-moi ${_currentAmountSats} sats via Lightning:\n\n$address');
  }

  String _toXof() {
    final sats = double.tryParse(_amountController.text) ?? 0;
    return (sats * 3.84).toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
