import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/services/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String email;
  final String userId;

  const OtpScreen({
    super.key,
    required this.email,
    required this.userId,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const Color _primary = Color(0xFF1C28F0);
  static const Color _error = Color(0xFFE83333);
  static const Color _success = Color(0xFF00B96B);

  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  bool _resendLoading = false;
  String? _resendMessage;

  String get _code =>
      _controllers.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    // Rediriger si authentifié
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
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.go(AppRoutes.register),
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFEEF0FF)),
                ),
              ),
              const SizedBox(height: 32),

              // Icon email
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.email_outlined,
                  color: _primary, size: 36),
              ),
              const SizedBox(height: 24),

              const Text('Vérifiez votre email',
                style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),

              Text.rich(TextSpan(
                text: 'Code envoyé à ',
                style: const TextStyle(
                  fontSize: 14, color: Color(0xFF8888AA)),
                children: [
                  TextSpan(
                    text: widget.email,
                    style: const TextStyle(
                      color: _primary, fontWeight: FontWeight.w700)),
                ],
              ), textAlign: TextAlign.center),

              const SizedBox(height: 8),
              const Text('Le code expire dans 1 heure',
                style: TextStyle(
                  fontSize: 12, color: Color(0xFF8888AA))),

              // Erreur
              if (authState.status == AuthStatus.error &&
                  authState.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _error.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: _error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(authState.error!,
                        style: const TextStyle(fontSize: 13, color: _error))),
                  ]),
                ),
              ],

              // Message renvoyer
              if (_resendMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEFFF6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _success.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline,
                      color: _success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_resendMessage!,
                        style: const TextStyle(
                          fontSize: 13, color: _success))),
                  ]),
                ),
              ],

              const SizedBox(height: 40),

              // 6 cases OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => SizedBox(
                  width: 48, height: 56,
                  child: TextFormField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: _primary),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE8E8F4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _primary, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && i < 5) {
                        _focusNodes[i + 1].requestFocus();
                      }
                      if (value.isEmpty && i > 0) {
                        _focusNodes[i - 1].requestFocus();
                      }
                      // Auto-vérifier quand les 6 cases sont remplies
                      if (_code.length == 6) {
                        _verify();
                      }
                    },
                  ),
                )),
              ),

              const SizedBox(height: 32),

              // Bouton vérifier
              ElevatedButton(
                onPressed: isLoading ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                  : const Text('Vérifier',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),

              const SizedBox(height: 16),

              // Renvoyer le code
              TextButton(
                onPressed: _resendLoading ? null : _resend,
                child: _resendLoading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: _primary))
                  : const Text('Renvoyer le code',
                      style: TextStyle(
                        color: _primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verify() async {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Entrez le code à 6 chiffres'),
          backgroundColor: _error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    await ref.read(authProvider.notifier).verifyOtp(
      widget.userId,
      _code,
    );
  }

  Future<void> _resend() async {
    setState(() {
      _resendLoading = true;
      _resendMessage = null;
    });

    final success = await ref.read(authProvider.notifier)
      .regenerateOtp(widget.userId);

    setState(() {
      _resendLoading = false;
      _resendMessage = success
        ? 'Nouveau code envoyé à ${widget.email}'
        : 'Erreur — réessayez plus tard';
    });

    // Effacer les cases
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }
}