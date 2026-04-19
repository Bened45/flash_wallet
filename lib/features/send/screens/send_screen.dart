import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/services/lnd_service.dart';
import '../../../shared/services/wallet_provider.dart';
import '../../../shared/services/contacts_service.dart';
import '../../../shared/services/payment_address_cache.dart';
import '../../../shared/models/transaction.dart';
import 'qr_scanner_screen.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  static const Color _primary = Color(0xFF1C28F0);
  static const Color _primaryLight = Color(0xFFEEF0FF);
  static const Color _error = Color(0xFFE83333);
  static const Color _border = Color(0xFFE8E8F4);
  static const Color _textSecondary = Color(0xFF8888AA);
  static const Color _success = Color(0xFF00B96B);

  bool _inSats = false;
  bool _isLoading = false;
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  List<Contact> _recentContacts = [];
  Map<String, dynamic>? _decodedInvoice;
  bool _isInvoiceMode = false;

  @override
  void initState() {
    super.initState();
    _loadRecentContacts();
    _addressController.addListener(_onAddressChanged);
  }

  void _onAddressChanged() {
    final text = _addressController.text.trim();
    final isInvoice = text.toLowerCase().startsWith('lnbc') ||
                      text.toLowerCase().startsWith('lntbs') ||
                      text.toLowerCase().startsWith('lnbcrt');

    setState(() {
      _isInvoiceMode = isInvoice;
      if (!isInvoice) _decodedInvoice = null;
    });

    // Dès qu'une invoice complète est collée, la décoder automatiquement.
    if (isInvoice && text.length > 20 && _decodedInvoice == null) {
      _autoDecodeInvoice(text);
    }
  }

  Future<void> _autoDecodeInvoice(String payReq) async {
    try {
      final decoded = await LndService().decodePayReq(payReq);
      if (mounted && _addressController.text.trim() == payReq) {
        setState(() => _decodedInvoice = decoded);
      }
    } catch (_) {
      // Silencieux — l'invoice est peut-être incomplète si l'utilisateur tape encore.
    }
  }

  Future<void> _loadRecentContacts() async {
    final contacts = await ContactsService.getRecentContacts();
    if (mounted) {
      setState(() => _recentContacts = contacts);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final lndBalance = ref.watch(lndBalanceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0A0A2E)),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
        title: const Text('Envoyer',
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
                const Expanded(
                  child: Text(
                    'Envoyez des sats instantanément via Lightning',
                    style: TextStyle(
                      fontSize: 12,
                      color: _primary,
                      fontWeight: FontWeight.w600,
                    )),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // Destinataire
            _buildAddressField(),
            const SizedBox(height: 16),

            // Montant
            _buildAmountCard(walletState, lndBalance),
            const SizedBox(height: 16),

            // Frais estimés
            _buildFeeRow(),
            const SizedBox(height: 16),

            // Note
            _buildNoteField(),
            const SizedBox(height: 16),

            // Contacts récents
            _buildRecents(),
            const SizedBox(height: 16),

            // Warning
            _buildWarning(),
            const SizedBox(height: 20),

            // Bouton envoyer
            _buildSendButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isInvoiceMode ? 'INVOICE LIGHTNING' : 'DESTINATAIRE',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: Color(0xFF8888AA),
                ),
              ),
              if (_isInvoiceMode && _decodedInvoice != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, size: 12, color: _success),
                      SizedBox(width: 4),
                      Text('Décodée',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _success,
                        )),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _addressController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _isInvoiceMode
                    ? 'Invoice Lightning collée'
                    : 'adresse Lightning ou @nom',
                  hintStyle: const TextStyle(
                    fontSize: 14, color: Color(0xFF8888AA)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _scanQRCode(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_scanner,
                  color: _primary, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showContactsModal(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.contacts_outlined,
                  color: _primary, size: 20),
              ),
            ),
          ]),
          if (_isInvoiceMode && _decodedInvoice != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _success.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet,
                        size: 16, color: _primary),
                      const SizedBox(width: 8),
                      Text(
                        '${_parseSats(_decodedInvoice) ?? '?'} sats',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0A0A2E),
                        ),
                      ),
                    ],
                  ),
                  if (_decodedInvoice!['memo'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Memo: ${_decodedInvoice!['memo']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// LND retourne num_satoshis comme String dans le JSON REST.
  static int? _parseSats(Map<String, dynamic>? d) {
    if (d == null) return null;
    final raw = d['num_satoshis'] ?? d['amount_sats'] ?? d['value'];
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  Widget _buildAmountCard(WalletState walletState, int lndBalance) {
    final invoiceAmount = _parseSats(_decodedInvoice);
    final isInvoiceWithAmount = invoiceAmount != null && invoiceAmount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('MONTANT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: Color(0xFF8888AA),
              )),
            if (!_isInvoiceMode || !isInvoiceWithAmount)
              GestureDetector(
                onTap: () => setState(() => _inSats = !_inSats),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    Text(_inSats ? 'sats' : 'XOF',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      )),
                    const Icon(Icons.swap_horiz,
                      size: 14, color: _primary),
                    Text(_inSats ? 'XOF' : 'sats',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      )),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isInvoiceMode && isInvoiceWithAmount)
          // Show invoice amount (read-only)
          Column(
            children: [
              Text(
                '$invoiceAmount sats',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                ),
              ),
              Text(
                '≈ ${(invoiceAmount * walletState.rateXof).toStringAsFixed(0)} XOF',
                style: const TextStyle(
                  fontSize: 13, color: _textSecondary)),
            ],
          )
        else
          // Normal amount input
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: _primary,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: _textSecondary.withOpacity(0.4),
              ),
              suffixText: _inSats ? 'sats' : 'XOF',
              suffixStyle: const TextStyle(
                fontSize: 20,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
        if (!_isInvoiceMode || !isInvoiceWithAmount)
          const Text('≈ 0 XOF',
            style: TextStyle(fontSize: 13, color: _textSecondary)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Solde: ${_formatSats(lndBalance)} sats',
            style: const TextStyle(
              fontSize: 11, color: _textSecondary)),
        ),
      ]),
    );
  }

  Widget _buildFeeRow() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x261C28F0)),
      ),
      child: Row(children: [
        const Icon(Icons.flash_on, color: _primary, size: 16),
        const SizedBox(width: 8),
        const Text('Frais estimés',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textSecondary,
          )),
        const Spacer(),
        const Text('~2 sats (≈ 1 XOF)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _primary,
          )),
      ]),
    );
  }

  Widget _buildNoteField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NOTE (OPTIONNEL)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Color(0xFF8888AA),
            )),
          const SizedBox(height: 8),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              hintText: 'Pour quoi est ce paiement ?',
              hintStyle: TextStyle(
                fontSize: 13, color: Color(0xFF8888AA)),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('RÉCENTS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: Color(0xFF8888AA),
          )),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: _recentContacts.isEmpty
              ? Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.people_outline,
                          size: 16,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Vos contacts récents\napparaîtront ici',
                        style: TextStyle(
                          fontSize: 11,
                          color: _textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentContacts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, i) {
                    final contact = _recentContacts[i];
                    return GestureDetector(
                      onTap: () => setState(() {
                        _addressController.text = contact.lightningAddress;
                      }),
                      child: Column(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Color(contact.color),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(contact.initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              )),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(contact.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A0A2E),
                          )),
                      ]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26E83333)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded,
          color: _error, size: 18),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Vérifiez l\'adresse avant d\'envoyer — les transactions Lightning sont irréversibles',
            style: TextStyle(fontSize: 12, color: _error),
          ),
        ),
      ]),
    );
  }

  Widget _buildSendButton() {
    // En mode invoice : le montant vient de _decodedInvoice, pas du champ texte.
    final hasAmount = _isInvoiceMode
        ? (_parseSats(_decodedInvoice) ?? 0) > 0
        : (_amountController.text.isNotEmpty && _amountController.text != '0');
    final hasAddress = _addressController.text.isNotEmpty;
    final isEnabled = hasAmount && hasAddress && !_isLoading;

    return ElevatedButton(
      onPressed: isEnabled ? _send : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled
          ? const Color(0xFF1C28F0)
          : const Color(0xFFCCCCDD),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: _isLoading
        ? const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2))
        : const Text('Envoyer →',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            )),
    );
  }

  Future<void> _send() async {
    setState(() => _isLoading = true);

    try {
      final input = _addressController.text.trim();
      if (input.isEmpty) {
        _showError('Veuillez entrer une adresse ou une invoice');
        return;
      }

      final walletState = ref.read(walletProvider);
      final lndBalance = ref.read(lndBalanceProvider);
      final lndNotifier = ref.read(lndProvider.notifier);
      final lnd = LndService();

      // ── Invoice BOLT11 directe ────────────────────────────────────────────
      if (_isInvoiceMode) {
        // Décoder d'abord pour connaître le montant (UX + validation solde).
        if (_decodedInvoice == null) {
          try {
            final decoded = await lnd.decodePayReq(input);
            setState(() => _decodedInvoice = decoded);
          } catch (_) {
            _showError('Invoice invalide ou nœud LND inaccessible');
            return;
          }
        }

        final invoiceAmount = _parseSats(_decodedInvoice) ?? 0;

        if (invoiceAmount <= 0) {
          _showError('Cette invoice n\'a pas de montant fixe');
          return;
        }
        if (invoiceAmount > lndBalance) {
          _showError('Solde insuffisant ($lndBalance sats disponibles)');
          return;
        }

        final result = await lndNotifier.payInvoice(input);
        if (!result.success) {
          _showError(result.error ?? 'Échec du paiement');
          return;
        }

        if (mounted) {
          context.go(AppRoutes.sendConfirm, extra: {
            'transaction': Transaction(
              id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
              type: 'SEND',
              status: 'COMPLETED',
              amountXof: (invoiceAmount * walletState.rateXof).toInt(),
              amountSats: invoiceAmount,
              exchangeRate: walletState.rateXof,
              receiverAddress: '${input.substring(0, 20)}...',
              note: _decodedInvoice!['description'] as String?
                  ?? _decodedInvoice!['memo'] as String?,
              lightningInvoice: input,
              createdAt: DateTime.now(),
            ),
            'receiverName': 'Paiement Lightning',
          });
        }
        return;
      }

      // ── Lightning Address → résolution LNURL → paiement LND ──────────────
      final amountStr = _amountController.text.trim();
      final amount = int.tryParse(amountStr) ?? 0;
      final note = _noteController.text.trim();

      if (!ContactsService.isValidLightningAddress(input)) {
        _showError('Adresse Lightning invalide (ex: nom@domain.com)');
        return;
      }
      if (amount <= 0) {
        _showError('Veuillez entrer un montant valide');
        return;
      }
      if (amount > lndBalance) {
        _showError('Solde insuffisant ($lndBalance sats disponibles)');
        return;
      }

      // 1. Résoudre l'adresse Lightning → obtenir une invoice BOLT11
      final String bolt11;
      try {
        bolt11 = await lnd.resolveLightningAddress(input, amount);
      } catch (e) {
        _showError('Impossible de résoudre l\'adresse : $e');
        return;
      }

      // 2. Payer via LND
      final result = await lndNotifier.payInvoice(bolt11);
      if (!result.success) {
        _showError(result.error ?? 'Échec de l\'envoi');
        return;
      }

      // 3. Mémoriser paymentHash → adresse Lightning pour l'historique
      if (result.paymentHash != null) {
        await PaymentAddressCache.save(result.paymentHash!, input);
      }

      if (mounted) {
        context.go(AppRoutes.sendConfirm, extra: {
          'transaction': Transaction(
            id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
            type: 'SEND',
            status: 'COMPLETED',
            amountXof: (amount * walletState.rateXof).toInt(),
            amountSats: amount,
            exchangeRate: walletState.rateXof,
            receiverAddress: input,
            note: note.isEmpty ? null : note,
            createdAt: DateTime.now(),
          ),
          'receiverName': _getDisplayNameFromAddress(input),
        });

        await ContactsService.saveRecentContact(
          name: _getDisplayNameFromAddress(input) ?? input.split('@').first,
          lightningAddress: input,
        );
        await _loadRecentContacts();
      }
    } catch (e) {
      _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatSats(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _scanQRCode(BuildContext context) async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showError('Permission caméra requise pour scanner un QR code');
      return;
    }

    // Navigate to QR scanner
    if (!mounted) return;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (result != null && mounted) {
      // Parse QR result - Lightning address, invoice, or LNURL
      if (result.toLowerCase().startsWith('lnbc') ||
          result.toLowerCase().startsWith('lntbs') ||
          result.toLowerCase().startsWith('lnbcrt')) {
        // It's a Lightning invoice
        setState(() {
          _addressController.text = result;
        });
      } else if (result.contains('@') || result.toLowerCase().startsWith('lnurl')) {
        // It's a Lightning address or LNURL
        setState(() {
          _addressController.text = result;
        });
      } else {
        _showError('QR code non reconnu. Scannez une adresse ou invoice Lightning.');
      }
    }
  }

  Future<void> _showContactsModal(BuildContext context) async {
    final contacts = await ContactsService.getRecentContacts();
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Contacts récents',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A0A2E),
              )),
            const SizedBox(height: 16),
            if (contacts.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Aucun contact récent.\nEnvoyez des sats pour commencer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textSecondary),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final contact = contacts[i];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _addressController.text = contact.lightningAddress;
                        });
                        Navigator.pop(context);
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
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: Color(contact.color),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(contact.initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(contact.name,
                                  style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                                Text(contact.lightningAddress,
                                  style: const TextStyle(
                                    fontSize: 12, color: _textSecondary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: _textSecondary),
                        ]),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _getDisplayNameFromAddress(String address) {
    // Check if address is in recent contacts
    final match = _recentContacts.firstWhere(
      (c) => c.lightningAddress == address,
      orElse: () => Contact(
        name: '',
        lightningAddress: address,
        color: 0xFFCCCCCC,
        lastUsed: DateTime.now(),
      ),
    );
    return match.name.isNotEmpty ? match.name : null;
  }

  @override
  void dispose() {
    _addressController.removeListener(_onAddressChanged);
    _addressController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}