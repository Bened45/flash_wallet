import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/services/auth_provider.dart';
import '../../../shared/services/lnd_service.dart';
import '../../../shared/services/wallet_provider.dart';
import '../../../shared/models/transaction.dart';

class ConvertScreen extends ConsumerStatefulWidget {
  const ConvertScreen({super.key});

  @override
  ConsumerState<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends ConsumerState<ConvertScreen> {
  static const Color _primary = Color(0xFF1C28F0);
  static const Color _primaryLight = Color(0xFFEEF0FF);
  static const Color _success = Color(0xFF00B96B);
  static const Color _successLight = Color(0xFFEEFFF6);
  static const Color _error = Color(0xFFE83333);
  static const Color _border = Color(0xFFE8E8F4);
  static const Color _textSecondary = Color(0xFF8888AA);
  int _selectedTab = 0; // 0=Vendre, 1=Acheter
  int _selectedPercent = -1;
  int _selectedXof = -1;
  bool _inputInSats = true; // true=sats, false=XOF

  final _satsController = TextEditingController();
  final _xofController = TextEditingController();
  bool _isUpdating = false;
  bool _isLoading = false;

  // Opérateur sélectionné — chargé depuis SharedPreferences
  String _selectedOperatorId = 'mtn';
  String _selectedOperator = 'MTN MoMo';
  String _selectedOperatorNumber = '';
  int _selectedOperatorColor = 0xFFFFCB05;
  bool _numberConfigured = false;

  // Opérateurs : données depuis AppConstants + champs UI supplémentaires
  static const List<Map<String, dynamic>> _operators = [
    {'id': 'mtn',     'name': 'MTN MoMo',    'short': 'MTN', 'color': 0xFFFFCB05, 'text': 0xFF000000},
    {'id': 'moov',    'name': 'Moov Money',   'short': 'MOV', 'color': 0xFF0052A5, 'text': 0xFFFFFFFF},
    {'id': 'celtiis', 'name': 'Celtiis',      'short': 'CEL', 'color': 0xFFE30613, 'text': 0xFFFFFFFF},
  ];

  @override
  void initState() {
    super.initState();
    _satsController.addListener(_onSatsChanged);
    _xofController.addListener(_onXofChanged);
    _loadOperatorFromPrefs();
  }

  Future<void> _loadOperatorFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Lire l'opérateur par défaut et son numéro
    final savedId = prefs.getString(AppConstants.operatorKey) ?? 'mtn';
    final savedNumber = prefs.getString(AppConstants.operatorNumberKey) ?? '';

    // Si le numéro est absent de la clé globale, chercher par opérateur
    String resolvedNumber = savedNumber;
    if (resolvedNumber.isEmpty) {
      resolvedNumber = prefs.getString('operator_${savedId}_number') ?? '';
    }

    final op = _operators.firstWhere(
      (o) => o['id'] == savedId,
      orElse: () => _operators.first,
    );

    if (mounted) {
      setState(() {
        _selectedOperatorId = op['id'] as String;
        _selectedOperator = op['name'] as String;
        _selectedOperatorColor = op['color'] as int;
        _selectedOperatorNumber = resolvedNumber;
        _numberConfigured = resolvedNumber.isNotEmpty;
      });
    }
  }

  double get _rate => ref.read(walletProvider).rateXof;

  void _onSatsChanged() {
    if (_isUpdating) return;
    _isUpdating = true;
    final rate = _rate;
    final sats = double.tryParse(_satsController.text) ?? 0;
    final xof = sats * rate;
    _xofController.text = xof > 0 ? xof.toStringAsFixed(0) : '';
    setState(() => _inputInSats = true);
    _isUpdating = false;
  }

  void _onXofChanged() {
    if (_isUpdating) return;
    _isUpdating = true;
    final rate = _rate;
    final xof = double.tryParse(_xofController.text) ?? 0;
    final sats = xof / rate;
    _satsController.text = sats > 0 ? sats.toStringAsFixed(0) : '';
    setState(() => _inputInSats = false);
    _isUpdating = false;
  }

  double get _satsValue =>
      double.tryParse(_satsController.text) ?? 0;

  double get _xofValue =>
      double.tryParse(_xofController.text) ?? 0;

  double get _feesXof {
    if (_selectedTab == 0) return _xofValue * 0.005;
    return _xofValue * 0.005;
  }

  double get _youReceive {
    if (_selectedTab == 0) {
      return _xofValue - _feesXof;
    } else {
      final rate = ref.read(walletProvider).rateXof;
      return (_xofValue - _feesXof) / rate;
    }
  }

  void _selectPercent(int index) {
    final lndBalance = ref.read(lndBalanceProvider);
    final rate = _rate;
    final percents = [0.25, 0.50, 1.0];
    final sats = (lndBalance * percents[index]).toInt();
    _isUpdating = true;
    _satsController.text = sats.toString();
    _xofController.text = (sats * rate).toStringAsFixed(0);
    _isUpdating = false;
    setState(() => _selectedPercent = index);
  }

  void _selectXof(int index) {
    final rate = _rate;
    final amounts = [1000.0, 5000.0, 10000.0];
    _isUpdating = true;
    _xofController.text = amounts[index].toStringAsFixed(0);
    _satsController.text = (amounts[index] / rate).toStringAsFixed(0);
    _isUpdating = false;
    setState(() => _selectedXof = index);
  }

  Future<void> _showOperatorSheet() async {
    // Charger les numéros configurés pour les afficher dans la sheet
    final prefs = await SharedPreferences.getInstance();
    final numbers = {
      for (final op in _operators)
        op['id'] as String:
            prefs.getString('operator_${op['id']}_number') ?? '',
    };

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
                  color: _border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Choisir un opérateur',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800,
                color: Color(0xFF0A0A2E))),
            const SizedBox(height: 16),
            ..._operators.map((op) {
              final id = op['id'] as String;
              final num = numbers[id] ?? '';
              final isSelected = _selectedOperatorId == id;
              return GestureDetector(
                onTap: () async {
                  final prefs2 = await SharedPreferences.getInstance();
                  final number = prefs2.getString('operator_${id}_number') ?? '';
                  if (mounted) {
                    setState(() {
                      _selectedOperatorId = id;
                      _selectedOperator = op['name'] as String;
                      _selectedOperatorColor = op['color'] as int;
                      _selectedOperatorNumber = number;
                      _numberConfigured = number.isNotEmpty;
                    });
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryLight : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? _primary : _border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Color(op['color'] as int),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(op['short'] as String,
                          style: TextStyle(
                            color: Color(op['text'] as int),
                            fontSize: 9, fontWeight: FontWeight.w800))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(op['name'] as String,
                            style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(
                            num.isNotEmpty ? num : 'Non configuré',
                            style: TextStyle(
                              fontSize: 12,
                              color: num.isNotEmpty
                                  ? _textSecondary
                                  : const Color(0xFFE83333))),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: _primary, size: 20),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSell = _selectedTab == 0;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0A0A2E)),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
        title: const Text('Convertir',
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
            _buildTabs(),
            const SizedBox(height: 20),
            _buildConversionCard(isSell),
            const SizedBox(height: 16),
            _buildOperatorCard(isSell),
            const SizedBox(height: 16),
            _buildAmountCard(isSell),
            const SizedBox(height: 16),
            _buildSummaryCard(isSell),
            const SizedBox(height: 16),
            _buildInfoBanner(isSell),
            const SizedBox(height: 20),
            _buildConvertButton(isSell),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        _tab('Acheter', 1),
        _tab('Vendre', 0),
      ]),
    );
  }

  Widget _tab(String label, int index) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedTab = index;
          _satsController.clear();
          _xofController.clear();
          _selectedPercent = -1;
          _selectedXof = -1;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? _primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : _textSecondary,
            )),
        ),
      ),
    );
  }

  Widget _buildConversionCard(bool isSell) {
    final bgColor = isSell ? _primaryLight : _successLight;
    final borderColor = isSell
        ? const Color(0x261C28F0)
        : const Color(0x2600B96B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // De
          Row(children: [
            _currencyBadge(isSell ? 'BTC' : 'XOF'),
            const SizedBox(width: 12),
            Text(isSell ? 'Satoshis' : 'Francs CFA',
              style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: Color(0xFF0A0A2E))),
            const Spacer(),
            Text(
              isSell
                ? '${_formatNum(_satsValue.toInt())} sats'
                : '${_formatNum(_xofValue.toInt())} XOF',
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: isSell ? _primary : _success)),
          ]),

          const SizedBox(height: 12),
          // Swap
          Center(
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedTab = _selectedTab == 0 ? 1 : 0;
                _satsController.clear();
                _xofController.clear();
                _selectedPercent = -1;
                _selectedXof = -1;
              }),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isSell ? _primary : _success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.swap_vert,
                  color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Vers
          Row(children: [
            _currencyBadge(isSell ? 'XOF' : 'BTC'),
            const SizedBox(width: 12),
            Text(isSell ? 'Francs CFA' : 'Satoshis',
              style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: Color(0xFF0A0A2E))),
            const Spacer(),
            Text(
              isSell
                ? '${_formatNum(_youReceive.toInt())} XOF'
                : '${_formatNum(_youReceive.toInt())} sats',
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: isSell ? _success : _primary)),
          ]),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final rate = ref.watch(walletProvider).rateXof;
              return Text(
                '1 sat = ${rate.toStringAsFixed(2)} XOF',
                style: const TextStyle(fontSize: 11, color: _textSecondary),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _currencyBadge(String label) {
    if (label == 'BTC') {
      return Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Text('₿', style: TextStyle(fontSize: 18, color: Colors.orange))),
      );
    }
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Text('🇧🇯', style: TextStyle(fontSize: 20))),
    );
  }

  Widget _buildOperatorCard(bool isSell) {
    final op = _operators.firstWhere(
      (o) => o['id'] == _selectedOperatorId,
      orElse: () => _operators.first,
    );
    final short = op['short'] as String;
    final textColor = Color(op['text'] as int);

    return GestureDetector(
      onTap: _showOperatorSheet,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _numberConfigured ? _border : const Color(0xFFFFD0D0),
            width: _numberConfigured ? 1 : 1.5,
          ),
        ),
        child: Column(
          children: [
            Row(children: [
              Text(isSell ? 'ENVOYER VERS' : 'PAYER AVEC',
                style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 1.5, color: _textSecondary)),
              const SizedBox(width: 12),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Color(_selectedOperatorColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(short,
                    style: TextStyle(
                      fontSize: 8, fontWeight: FontWeight.w800,
                      color: textColor))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedOperator,
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(
                      _numberConfigured
                          ? _selectedOperatorNumber
                          : 'Non configuré — toucher pour configurer',
                      style: TextStyle(
                        fontSize: 11,
                        color: _numberConfigured
                            ? _textSecondary
                            : const Color(0xFFE83333))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _textSecondary),
            ]),
            if (!_numberConfigured) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFE83333), size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Configurez votre numéro Mobile Money dans Profil → Opérateurs',
                      style: TextStyle(
                        fontSize: 11, color: Color(0xFFE83333),
                        fontWeight: FontWeight.w500))),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(bool isSell) {
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
          // Quick options
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              if (isSell) ...[
                ...['25%', '50%', '100%'].asMap().entries.map((e) {
                  final isSelected = _selectedPercent == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _selectPercent(e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? _primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? _primary : _border)),
                        child: Text(e.value,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : _textSecondary)),
                      ),
                    ),
                  );
                }),
              ] else ...[
                ...['1 000 XOF', '5 000 XOF', '10 000 XOF']
                    .asMap().entries.map((e) {
                  final isSelected = _selectedXof == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _selectXof(e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? _primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? _primary : _border)),
                        child: Text(e.value,
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : _textSecondary)),
                      ),
                    ),
                  );
                }),
              ],
            ]),
          ),
          const SizedBox(height: 16),

          // Input sats
          _buildDualInput(
            controller: _satsController,
            label: 'sats',
            color: _primary,
            hint: '0',
          ),
          const SizedBox(height: 4),
          const Center(
            child: Icon(Icons.swap_vert, color: _textSecondary, size: 20)),
          const SizedBox(height: 4),

          // Input XOF
          _buildDualInput(
            controller: _xofController,
            label: 'XOF',
            color: _success,
            hint: '0',
          ),

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Consumer(
              builder: (context, ref, child) {
                final lndBalance = ref.watch(lndBalanceProvider);
                return Text(
                  isSell
                    ? 'Solde: ${_formatNum(lndBalance)} sats'
                    : 'Minimum: 100 XOF',
                  style: const TextStyle(fontSize: 11, color: _textSecondary));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDualInput({
    required TextEditingController controller,
    required String label,
    required Color color,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _textSecondary.withOpacity(0.3),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            )),
        ),
      ]),
    );
  }

  Widget _buildSummaryCard(bool isSell) {
    final bgColor = isSell ? _primaryLight : _successLight;
    final borderColor = isSell
        ? const Color(0x261C28F0)
        : const Color(0x2600B96B);
    final accentColor = isSell ? _primary : _success;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _summaryRow('Montant',
            isSell
              ? '${_formatNum(_satsValue.toInt())} sats'
              : '${_formatNum(_xofValue.toInt())} XOF'),
          const SizedBox(height: 8),
          _summaryRow('Taux', '1 sat = ${ref.watch(walletProvider).rateXof.toStringAsFixed(2)} XOF'),
          const SizedBox(height: 8),
          _summaryRow('Frais Flash (0,5%)',
            '${_formatNum(_feesXof.toInt())} XOF'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(children: [
            const Text('Vous recevez',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: Color(0xFF0A0A2E))),
            const Spacer(),
            Text(
              isSell
                ? '${_formatNum(_youReceive.toInt())} XOF'
                : '${_formatNum(_youReceive.toInt())} sats',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900,
                color: accentColor)),
          ]),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(children: [
      Text(label,
        style: const TextStyle(fontSize: 13, color: _textSecondary)),
      const Spacer(),
      Text(value,
        style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: Color(0xFF0A0A2E))),
    ]);
  }

  Widget _buildInfoBanner(bool isSell) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline, color: _primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isSell
              ? 'Les fonds arrivent sur votre Mobile Money en moins de 2 minutes'
              : 'Les sats arrivent instantanément dans votre wallet',
            style: const TextStyle(fontSize: 12, color: _textSecondary),
          ),
        ),
      ]),
    );
  }

  Widget _buildConvertButton(bool isSell) {
    final hasAmount = _satsValue > 0;
    return ElevatedButton(
      onPressed: hasAmount && !_isLoading ? () => _convert(isSell) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: hasAmount
          ? (isSell ? _primary : _success)
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
        : Text(
            isSell
              ? 'Vendre → $_selectedOperator'
              : 'Acheter → Wallet Flash',
            style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: Colors.white)),
    );
  }

  Future<void> _convert(bool isSell) async {
    // Validation préalable
    if (!_numberConfigured || _selectedOperatorNumber.isEmpty) {
      _showError('Numéro Mobile Money non configuré — allez dans Profil → Opérateurs');
      return;
    }

    final amountSats = _satsValue.toInt();
    final amountXof = _xofValue.toInt();

    if (amountSats <= 0 || amountXof <= 0) {
      _showError('Veuillez entrer un montant valide');
      return;
    }

    final lndBalance = ref.read(lndBalanceProvider);
    if (isSell && amountSats > lndBalance) {
      _showError('Solde insuffisant — vous avez ${_formatNum(lndBalance)} sats');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authProvider);
      final lndNotifier = ref.read(lndProvider.notifier);
      final flashApi = ref.read(flashApiProvider);
      final rate = ref.read(walletProvider).rateXof;
      String txId = 'tx_${DateTime.now().millisecondsSinceEpoch}';
      String txStatus = 'PENDING';

      if (!isSell) {
        // ── ACHETER : XOF → BTC ─────────────────────────────────────────────
        // 1. Générer une invoice LND pour que Flash puisse nous payer
        final bolt11 = await lndNotifier.createInvoice(
          amountSats,
          'Achat Bitcoin Flash — $amountXof XOF',
        );
        if (bolt11 == null) {
          _showError('Impossible de créer l\'invoice LND');
          return;
        }

        // 2. Envoyer la transaction BUY à Flash
        //    Flash débite MTN MoMo et paie notre invoice LND
        final res = await flashApi.buyBitcoin(
          amountXof: amountXof,
          lightningAddress: bolt11,
          mobileMoneyNumber: _selectedOperatorNumber,
        );
        txId = res['transaction']?['id']?.toString()
            ?? txId;
        txStatus = 'PENDING'; // Flash traite le paiement Mobile Money

      } else {
        // ── VENDRE : BTC → XOF ──────────────────────────────────────────────
        // 1. Demander à Flash de créer la transaction SELL
        final res = await flashApi.sellBitcoin(
          amountXof: amountXof,
          lightningAddress: authState.lightningAddress,
          mobileMoneyNumber: _selectedOperatorNumber,
        );
        txId = res['transaction']?['id']?.toString() ?? txId;

        // 2. Flash retourne une invoice Lightning dans res['invoice']
        final invoice = res['invoice'] as String?;
        if (invoice == null || invoice.isEmpty) {
          _showError('Flash n\'a pas retourné d\'invoice Lightning');
          return;
        }

        // 3. Payer l'invoice via LND (libère les sats vers Flash)
        final result = await lndNotifier.payInvoice(invoice);
        if (!result.success) {
          _showError('Paiement LND échoué : ${result.error ?? 'erreur inconnue'}');
          return;
        }
        txStatus = 'COMPLETED';
      }

      // Rafraîchir le solde LND
      await lndNotifier.refresh();

      if (mounted) {
        context.go(AppRoutes.convertConfirm, extra: {
          'transaction': Transaction(
            id: txId,
            type: isSell ? 'SELL_BITCOIN' : 'BUY_BITCOIN',
            status: txStatus,
            amountXof: amountXof,
            amountSats: amountSats,
            exchangeRate: rate,
            receiverAddress: isSell ? _selectedOperatorNumber : authState.lightningAddress,
            mobileMoneyNumber: _selectedOperatorNumber,
            mobileMoneyOperator: _selectedOperator,
            createdAt: DateTime.now(),
          ),
          'isSell': isSell,
        });
      }
    } catch (e) {
      final msg = e.toString()
          .replaceAll('DioException [connection error]: ', '')
          .replaceAll('Exception: ', '')
          .split('\n').first
          .trim();
      _showError('Erreur : $msg');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  String _formatNum(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ');
  }

  @override
  void dispose() {
    _satsController.dispose();
    _xofController.dispose();
    super.dispose();
  }
}