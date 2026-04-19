import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/auto_convert_service.dart';

class AutoConvertSettingsScreen extends ConsumerStatefulWidget {
  const AutoConvertSettingsScreen({super.key});

  @override
  ConsumerState<AutoConvertSettingsScreen> createState() => _AutoConvertSettingsScreenState();
}

class _AutoConvertSettingsScreenState extends ConsumerState<AutoConvertSettingsScreen> {
  static const Color _primary = Color(0xFF1C28F0);
  static const Color _primaryLight = Color(0xFFEEF0FF);
  static const Color _success = Color(0xFF00B96B);
  static const Color _border = Color(0xFFE8E8F4);
  static const Color _textSecondary = Color(0xFF8888AA);

  late AutoConvertSettings _settings;
  bool _isLoading = true;

  final List<Map<String, dynamic>> _operators = [
    {'name': 'MTN MoMo', 'short': 'MTN', 'color': 0xFFFFCB05, 'text': 0xFF000000},
    {'name': 'Moov Money', 'short': 'MOV', 'color': 0xFF0052A5, 'text': 0xFFFFFFFF},
    {'name': 'Celtiis', 'short': 'CEL', 'color': 0xFFE30613, 'text': 0xFFFFFFFF},
    {'name': 'Togocel', 'short': 'TOG', 'color': 0xFF00A651, 'text': 0xFFFFFFFF},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await AutoConvertService.getSettings();
    if (mounted) {
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    await AutoConvertService.saveSettings(_settings);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0A0A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Conversion Automatique',
          style: TextStyle(
            color: Color(0xFF0A0A2E),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle Card
            _buildToggleCard(),
            const SizedBox(height: 20),

            if (_settings.enabled) ...[
              // Mode Selection
              _buildModeSelection(),
              const SizedBox(height: 20),

              // Threshold
              _buildThresholdCard(),
              const SizedBox(height: 20),

              // Mobile Money Operator
              _buildOperatorCard(),
              const SizedBox(height: 20),

              // Info Banner
              _buildInfoBanner(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _settings.enabled ? _success.withOpacity(0.1) : _primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.sync,
              color: _settings.enabled ? _success : _primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conversion Automatique',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _settings.enabled
                      ? 'Activée - Vos sats seront convertés automatiquement'
                      : 'Désactivée - Activez pour convertir automatiquement',
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _settings.enabled,
            onChanged: (value) async {
              setState(() {
                _settings = _settings.copyWith(enabled: value);
              });
              await _saveSettings();
            },
            activeColor: _success,
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MODE DE CONVERSION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _buildModeOption(
            icon: Icons.percent,
            title: 'Tout convertir',
            subtitle: 'Convertir 100% des sats reçus',
            isSelected: _settings.convertAllOnReceive,
            onTap: () async {
              setState(() {
                _settings = _settings.copyWith(convertAllOnReceive: true);
              });
              await _saveSettings();
            },
          ),
          const SizedBox(height: 8),
          _buildModeOption(
            icon: Icons.attach_money,
            title: 'Montant fixe',
            subtitle: 'Convertir un montant XOF spécifique',
            isSelected: !_settings.convertAllOnReceive,
            onTap: () async {
              setState(() {
                _settings = _settings.copyWith(convertAllOnReceive: false);
              });
              await _saveSettings();
            },
          ),
          if (!_settings.convertAllOnReceive) ...[
            const SizedBox(height: 12),
            _buildFixedAmountInput(),
          ],
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _primaryLight : const Color(0xFFF5F5FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primary : _border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? _primary : _textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? _primary : const Color(0xFF0A0A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Radio<bool>(
              value: isSelected,
              groupValue: true,
              onChanged: (_) => onTap(),
              activeColor: _primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedAmountInput() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Montant XOF à convertir:',
              style: TextStyle(fontSize: 12, color: _textSecondary),
            ),
          ),
          SizedBox(
            width: 120,
            child: TextFormField(
              initialValue: _settings.fixedAmountXof > 0
                  ? _settings.fixedAmountXof.toStringAsFixed(0)
                  : '',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                hintText: '0',
                suffixText: 'XOF',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (value) async {
                final amount = double.tryParse(value) ?? 0;
                setState(() {
                  _settings = _settings.copyWith(fixedAmountXof: amount);
                });
                await _saveSettings();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SEUIL DE DÉCLENCHEMENT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_settings.thresholdPercent.toInt()}%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                ),
              ),
              Text(
                'du solde',
                style: TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: _settings.thresholdPercent,
            min: 10,
            max: 100,
            divisions: 9,
            label: '${_settings.thresholdPercent.toInt()}%',
            activeColor: _primary,
            onChanged: (value) async {
              setState(() {
                _settings = _settings.copyWith(thresholdPercent: value);
              });
              await _saveSettings();
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10%', style: TextStyle(fontSize: 10, color: _textSecondary)),
              Text('100%', style: TextStyle(fontSize: 10, color: _textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OPÉRATEUR MOBILE MONEY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ..._operators.map((op) => GestureDetector(
                onTap: () async {
                  setState(() {
                    _settings = _settings.copyWith(
                      mobileMoneyOperator: op['name'] as String,
                    );
                  });
                  await _saveSettings();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _settings.mobileMoneyOperator == op['name']
                        ? _primaryLight
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _settings.mobileMoneyOperator == op['name']
                          ? _primary
                          : _border,
                      width: _settings.mobileMoneyOperator == op['name'] ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(op['color'] as int),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            op['short'] as String,
                            style: TextStyle(
                              color: Color(op['text'] as int),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          op['name'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_settings.mobileMoneyOperator == op['name'])
                        const Icon(Icons.check_circle, color: _primary, size: 20),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 12),
          const Text(
            'Numéro Mobile Money (optionnel)',
            style: TextStyle(fontSize: 12, color: _textSecondary),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _settings.mobileMoneyNumber,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: '+229 97 00 00 00',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) async {
              setState(() {
                _settings = _settings.copyWith(mobileMoneyNumber: value);
              });
              await _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x261C28F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _primary, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Les fonds seront envoyés sur votre compte Mobile Money en moins de 2 minutes après conversion',
              style: TextStyle(
                fontSize: 12,
                color: _primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
