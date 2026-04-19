import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/services/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const Color _primary = Color(0xFF1C28F0);
  static const Color _error = Color(0xFFE83333);

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => context.go(AppRoutes.welcome),
                icon: const Icon(Icons.arrow_back),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEEF0FF)),
              ),
              const SizedBox(height: 24),
              const Text('Créez votre compte',
                style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'Rejoignez Flash pour vos transferts ultra-rapides.',
                style: TextStyle(
                  fontSize: 14, color: Color(0xFF8888AA))),

              // Erreur
              if (authState.status == AuthStatus.error &&
                  authState.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _error.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                      color: _error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(authState.error!,
                        style: const TextStyle(
                          fontSize: 13, color: _error))),
                  ]),
                ),
              ],

              const SizedBox(height: 32),
              _field('Nom complet', 'John Doe',
                Icons.person_outline, _nameController),
              const SizedBox(height: 16),
              _field('Email', 'john@exemple.com',
                Icons.email_outlined, _emailController,
                keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFE8E8F4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('🇧🇯 BJ',
                    style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _whatsappController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+229...',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _field('Mot de passe', '••••••••',
                Icons.lock_outlined, _passwordController,
                isPassword: true, obscureToggle: () => setState(() => _obscure = !_obscure), obscure: _obscure),
              const SizedBox(height: 16),
              _field('Confirmer mot de passe', '••••••••',
                Icons.lock_outlined, _confirmController,
                isPassword: true, obscureToggle: () => setState(() => _obscureConfirm = !_obscureConfirm), obscure: _obscureConfirm),
              const SizedBox(height: 16),
              Row(children: [
                Checkbox(
                  value: _acceptTerms,
                  onChanged: (v) => setState(
                    () => _acceptTerms = v ?? false),
                  activeColor: _primary,
                ),
                const Expanded(
                  child: Text.rich(TextSpan(
                    text: 'J\'accepte les ',
                    style: TextStyle(
                      color: Color(0xFF8888AA), fontSize: 13),
                    children: [
                      TextSpan(
                        text: 'Conditions d\'utilisation',
                        style: TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w600)),
                      TextSpan(text: ' et la '),
                      TextSpan(
                        text: 'Politique de confidentialité',
                        style: TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w600)),
                    ],
                  )),
                ),
              ]),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_acceptTerms && !isLoading)
                  ? _register : null,
                child: isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                  : const Text('S\'inscrire →'),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.login),
                  child: const Text.rich(TextSpan(
                    text: 'Déjà un compte ? ',
                    style: TextStyle(
                      color: Color(0xFF8888AA), fontSize: 14),
                    children: [
                      TextSpan(
                        text: 'Se connecter',
                        style: TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w700)),
                    ],
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Les mots de passe ne correspondent pas'),
          backgroundColor: const Color(0xFFE83333),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final res = await ref.read(authProvider.notifier).register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      whatsapp: _whatsappController.text.trim(),
    );

    if (res != null && mounted) {
      final userId = res['data']['user']['id'] as String;
      context.go(AppRoutes.otp,
        extra: {
          'email': _emailController.text.trim(),
          'userId': userId,
        },
      );
    }
  }

  Widget _field(
    String label, String hint, IconData icon,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? obscureToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword ? obscure : false,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: isPassword ? IconButton(
              icon: Icon(obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined),
              onPressed: obscureToggle,
            ) : null,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
