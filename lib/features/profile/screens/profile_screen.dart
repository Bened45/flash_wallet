import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/services/auth_provider.dart';
import '../../../shared/services/wallet_provider.dart';
import '../../convert/screens/auto_convert_settings_screen.dart';
import '../../settings/screens/operator_settings_screen.dart';
import '../../../shared/services/currency_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const Color _primary = Color(0xFF1C28F0);
  static const Color _primaryLight = Color(0xFFEEF0FF);
  static const Color _success = Color(0xFF00B96B);
  static const Color _error = Color(0xFFE83333);
  static const Color _border = Color(0xFFE8E8F4);
  static const Color _textSecondary = Color(0xFF8888AA);

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final walletState = ref.watch(walletProvider);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context, authState)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildKycCard(),
                const SizedBox(height: 20),
                _buildSection('MON COMPTE', [
                  _buildMenuItem(
                    Icons.person_outline,
                    'Informations personnelles',
                    'Nom, email, WhatsApp',
                    () {},
                  ),
                  _buildMenuItem(
                    Icons.phone_android_outlined,
                    'Opérateurs Mobile Money',
                    'MTN MoMo configuré',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OperatorSettingsScreen()),
                    ),
                  ),
                  _buildMenuItem(
                    Icons.notifications_outlined,
                    'Notifications',
                    'WhatsApp, email',
                    () {},
                  ),
                  _buildMenuItem(
                    Icons.lock_outlined,
                    'Sécurité',
                    'Mot de passe, PIN',
                    () {},
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('CONVERSION AUTOMATIQUE', [
                  _buildMenuItem(
                    Icons.sync,
                    'Paramètres de conversion',
                    'Seuil, opérateur par défaut',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AutoConvertSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    Icons.history,
                    'Historique des conversions',
                    'Toutes les conversions effectuées',
                    () {},
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('PRÉFÉRENCES', [
                  _buildMenuItemWithValue(
                    Icons.language_outlined,
                    'Langue',
                    'Français',
                    () {},
                  ),
                  _buildMenuItemWithValue(
                    Icons.attach_money_outlined,
                    'Devise d\'affichage',
                    ref.watch(currencyProvider).selected.code,
                    () => _showCurrencyPicker(context),
                  ),
                  _buildMenuItemWithValue(
                    Icons.dark_mode_outlined,
                    'Thème',
                    'Clair',
                    () {},
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('SUPPORT', [
                  _buildMenuItem(
                    Icons.chat_outlined,
                    'Contacter le support',
                    'Via WhatsApp',
                    () {},
                  ),
                  _buildMenuItem(
                    Icons.description_outlined,
                    'Conditions d\'utilisation',
                    '',
                    () {},
                  ),
                  _buildMenuItem(
                    Icons.privacy_tip_outlined,
                    'Politique de confidentialité',
                    '',
                    () {},
                  ),
                  _buildMenuItemWithValue(
                    Icons.info_outlined,
                    'Version de l\'app',
                    'v1.0.0',
                    () {},
                    isLast: true,
                    showChevron: false,
                  ),
                ]),
                const SizedBox(height: 24),
                _buildLogoutButton(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthState authState) {
    final topPadding = MediaQuery.of(context).padding.top;
    final userName = authState.name ?? 'Utilisateur';
    final userEmail = authState.email ?? '';
    final lightningAddress = authState.lightningAddress;
    final userInitials = authState.initials;
    
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 32),
      child: Column(
        children: [
          // Top bar
          Row(children: [
            const Text('Profil',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              )),
            const Spacer(),
            // Edit button
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Icon(Icons.edit_outlined,
                color: Colors.white, size: 18),
            ),
          ]),
          const SizedBox(height: 24),
          // Avatar
          Stack(
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4), width: 2),
                ),
                child: Center(
                  child: Text(userInitials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    )),
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 24, height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt,
                    color: _primary, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            )),
          const SizedBox(height: 4),
          Text(userEmail,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            )),
          const SizedBox(height: 10),
          // Lightning address badge
          if (lightningAddress.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flash_on, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(lightningAddress,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKycCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_user_outlined,
                color: _primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vérification KYC',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('Niveau 1 — Basique',
                    style: TextStyle(
                      fontSize: 11, color: _textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Compléter →',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                )),
            ),
          ]),
          const SizedBox(height: 14),
          // Progress bar
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _kycLevel('Basique', true),
                  _kycLevel('Intermédiaire', false),
                  _kycLevel('Avancé', false),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.33,
                  backgroundColor: _border,
                  valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kycLevel(String label, bool isActive) {
    return Text(label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: isActive ? _primary : _textSecondary,
      ));
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: _textSecondary,
            )),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isLast = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(
            bottom: BorderSide(color: _border),
          ),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                    style: const TextStyle(
                      fontSize: 11, color: _textSecondary)),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: _textSecondary, size: 20),
        ]),
      ),
    );
  }

  Widget _buildMenuItemWithValue(
    IconData icon,
    String title,
    String value,
    VoidCallback onTap, {
    bool isLast = false,
    bool showChevron = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(
            bottom: BorderSide(color: _border),
          ),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Text(value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
            )),
          if (showChevron) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: _textSecondary, size: 20),
          ],
        ]),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final current = ref.watch(currencyProvider).selected;
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Devise d\'affichage',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: Color(0xFF0A0A2E))),
                const SizedBox(height: 6),
                const Text(
                  'Le solde s\'affichera dans cette devise sur le dashboard.',
                  style: TextStyle(fontSize: 12, color: _textSecondary)),
                const SizedBox(height: 20),
                ...DisplayCurrency.values.map((c) {
                  final isSelected = c == current;
                  return GestureDetector(
                    onTap: () {
                      ref.read(currencyProvider.notifier).select(c);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryLight : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? _primary : _border,
                          width: isSelected ? 1.5 : 1),
                      ),
                      child: Row(children: [
                        Text(c.flag,
                          style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(c.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? _primary
                                  : const Color(0xFF0A0A2E)))),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                            color: _primary, size: 20),
                      ]),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
            title: const Text('Se déconnecter',
              style: TextStyle(fontWeight: FontWeight.w800)),
            content: const Text(
              'Êtes-vous sûr de vouloir vous déconnecter ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler',
                  style: TextStyle(color: _textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    context.go(AppRoutes.welcome);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Déconnecter',
                  style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: _error,
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: _error, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text('Se déconnecter',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _error,
        )),
    );
  }
}