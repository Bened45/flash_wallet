import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';

// ── Clés SharedPreferences ────────────────────────────────────────────────────

class _Keys {
  static const String defaultOperator = 'default_operator';
  static String enabled(String id) => 'operator_${id}_enabled';
  static String number(String id) => 'operator_${id}_number';
}

// ── Modèle local ──────────────────────────────────────────────────────────────

class _OperatorState {
  bool enabled;
  final TextEditingController controller;

  _OperatorState({required this.enabled, required String number})
      : controller = TextEditingController(text: number);

  void dispose() => controller.dispose();
}

// ── Écran ─────────────────────────────────────────────────────────────────────

class OperatorSettingsScreen extends StatefulWidget {
  const OperatorSettingsScreen({super.key});

  @override
  State<OperatorSettingsScreen> createState() => _OperatorSettingsScreenState();
}

class _OperatorSettingsScreenState extends State<OperatorSettingsScreen> {
  static const Color _primary = Color(0xFF1C28F0);
  static const Color _primaryLight = Color(0xFFEEF0FF);
  static const Color _success = Color(0xFF00B96B);
  static const Color _border = Color(0xFFE8E8F4);
  static const Color _textSecondary = Color(0xFF8888AA);
  static const Color _bg = Color(0xFFF5F5FA);

  final Map<String, _OperatorState> _states = {};
  String _defaultId = 'mtn';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final s in _states.values) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultId = prefs.getString(_Keys.defaultOperator) ?? 'mtn';
    final states = <String, _OperatorState>{};
    for (final op in AppConstants.operators) {
      final id = op['id'] as String;
      states[id] = _OperatorState(
        enabled: prefs.getBool(_Keys.enabled(id)) ?? (id == 'mtn'),
        number: prefs.getString(_Keys.number(id)) ?? '',
      );
    }
    if (mounted) {
      setState(() {
        _states.addAll(states);
        _defaultId = defaultId;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    // Valider que l'opérateur par défaut a un numéro
    final defaultNumber = _states[_defaultId]?.controller.text.trim() ?? '';
    if (defaultNumber.isEmpty) {
      _showError('Entrez le numéro de l\'opérateur par défaut.');
      return;
    }
    if (!_states[_defaultId]!.enabled) {
      _showError('L\'opérateur par défaut doit être activé.');
      return;
    }

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_Keys.defaultOperator, _defaultId);
    for (final op in AppConstants.operators) {
      final id = op['id'] as String;
      final s = _states[id]!;
      await prefs.setBool(_Keys.enabled(id), s.enabled);
      await prefs.setString(_Keys.number(id), s.controller.text.trim());
    }
    // Rétro-compat : clés utilisées par AutoConvert
    await prefs.setString(AppConstants.operatorKey, _defaultId);
    await prefs.setString(AppConstants.operatorNumberKey, defaultNumber);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Opérateurs enregistrés'),
          backgroundColor: _success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFE83333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5FA),
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0A0A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Opérateurs Mobile Money',
          style: TextStyle(
            color: Color(0xFF0A0A2E),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoBanner(),
                  const SizedBox(height: 20),
                  _buildSectionLabel('OPÉRATEURS CONFIGURÉS'),
                  const SizedBox(height: 10),
                  ...AppConstants.operators.map((op) => _buildOperatorCard(op)),
                  const SizedBox(height: 20),
                  _buildSectionLabel('OPÉRATEUR PAR DÉFAUT'),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      'Utilisé pour la conversion automatique',
                      style: TextStyle(fontSize: 12, color: _textSecondary),
                    ),
                  ),
                  ...AppConstants.operators.map((op) => _buildDefaultRadio(op)),
                ],
              ),
            ),
          ),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x261C28F0)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline, color: _primary, size: 18),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Configurez vos comptes Mobile Money pour recevoir vos conversions Bitcoin → XOF',
            style: TextStyle(
              fontSize: 12, color: _primary, fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: _textSecondary,
        ),
      ),
    );
  }

  Widget _buildOperatorCard(Map<String, dynamic> op) {
    final id = op['id'] as String;
    final s = _states[id]!;
    final opColor = Color(op['color'] as int);
    final textColor = Color(op['textColor'] as int);
    final isDefault = _defaultId == id;
    final short = (op['name'] as String).split(' ').first.toUpperCase();
    if (short.length > 3) short.substring(0, 3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: s.enabled ? opColor.withValues(alpha: 0.4) : _border,
          width: s.enabled ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // En-tête opérateur
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: opColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    short.length >= 3 ? short.substring(0, 3) : short,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(op['name'] as String,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                    if (isDefault) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Par défaut',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                          )),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: s.enabled,
                onChanged: (v) => setState(() => s.enabled = v),
                activeColor: opColor,
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return opColor.withValues(alpha: 0.3);
                  }
                  return _border;
                }),
              ),
            ]),
          ),
          // Champ numéro (toujours visible, grisé si désactivé)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: AnimatedOpacity(
              opacity: s.enabled ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  color: s.enabled ? const Color(0xFFF8F8FC) : _bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(children: [
                  const SizedBox(width: 12),
                  Icon(Icons.phone_android_outlined,
                    size: 16, color: _textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: s.controller,
                      enabled: s.enabled,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: op['prefix'] as String? ?? '+229',
                        hintStyle: const TextStyle(
                          color: _textSecondary, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12),
                      ),
                    ),
                  ),
                  if (s.controller.text.isNotEmpty && s.enabled)
                    GestureDetector(
                      onTap: () => setState(() => s.controller.clear()),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.clear,
                          size: 16, color: _textSecondary),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultRadio(Map<String, dynamic> op) {
    final id = op['id'] as String;
    final s = _states[id]!;
    final opColor = Color(op['color'] as int);
    final isSelected = _defaultId == id;
    final isDisabled = !s.enabled;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () => setState(() => _defaultId = id),
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: opColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(op['name'] as String,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? _primary : const Color(0xFF0A0A2E),
                )),
            ),
            if (isDisabled)
              const Text('Désactivé',
                style: TextStyle(fontSize: 11, color: _textSecondary))
            else
              Radio<String>(
                value: id,
                groupValue: _defaultId,
                onChanged: (v) => setState(() => _defaultId = v!),
                activeColor: _primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            disabledBackgroundColor: _primary.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
              : const Text(
                  'Enregistrer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  )),
        ),
      ),
    );
  }
}
