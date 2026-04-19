import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/services/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const Color _primary = Color(0xFF1C28F0);
  static const Color _error = Color(0xFFE83333);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    // Rediriger si connecté
    ref.listen(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go(AppRoutes.dashboard);
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.flash_on,
                    color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(height: 32),
              const Text('Bienvenue sur Flash',
                style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'Gérez vos finances avec la vitesse de l\'éclair.',
                style: TextStyle(fontSize: 14,
                  color: Color(0xFF8888AA))),

              // Erreur API
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
              const Text('Email',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'nom@exemple.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Mot de passe',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Mot de passe oublié ?',
                    style: TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isLoading ? null : _login,
                child: isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ))
                  : const Text('Se connecter →'),
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.register),
                  child: const Text.rich(TextSpan(
                    text: 'Pas encore de compte ? ',
                    style: TextStyle(
                      color: Color(0xFF8888AA), fontSize: 14),
                    children: [
                      TextSpan(
                        text: 'S\'inscrire',
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

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Remplissez tous les champs'),
          backgroundColor: const Color(0xFFE83333),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    await ref.read(authProvider.notifier).login(email, password);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
