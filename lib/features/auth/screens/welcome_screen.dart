import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // ── Palette Flash — strictement ces couleurs ──────────────────────────────
  static const Color _primary      = Color(0xFF1C28F0);
  static const Color _primaryLight = Color(0xFFEEF0FF);
  static const Color _textDark     = Color(0xFF0A0A2E);
  static const Color _textSecondary = Color(0xFF8888AA);
  static const Color _border       = Color(0xFFE8E8F4);

  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardSlide> _slides = [
    _OnboardSlide(
      icon: Icons.flash_on,
      title: 'Bitcoin en quelques secondes',
      description:
          'Envoyez et recevez des sats instantanément via le réseau Lightning partout dans le monde.',
    ),
    _OnboardSlide(
      icon: Icons.swap_horiz_rounded,
      title: 'Convertissez en XOF',
      description:
          'Achetez du Bitcoin depuis votre Mobile Money (MTN, Moov, Celtiis) dès 100 XOF.',
    ),
    _OnboardSlide(
      icon: Icons.shield_outlined,
      title: 'Vos fonds, votre contrôle',
      description:
          'Sécurisé par la technologie Lightning Network. Vos transactions sont rapides, fiables et transparentes.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      context.go(AppRoutes.register);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Bouton passer
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 20, 0),
                child: _currentPage < _slides.length - 1
                    ? TextButton(
                        onPressed: () => context.go(AppRoutes.register),
                        child: const Text(
                          'Passer',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : const SizedBox(height: 40),
              ),
            ),

            // Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, index) => _buildSlide(_slides[index]),
              ),
            ),

            // Indicateurs de page
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? _primary : _border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // Bouton principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _currentPage < _slides.length - 1
                      ? 'Suivant →'
                      : 'Créer un compte →',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Lien connexion
            GestureDetector(
              onTap: () => context.go(AppRoutes.login),
              child: const Text.rich(
                TextSpan(
                  text: 'Déjà un compte ? ',
                  style: TextStyle(color: _textSecondary, fontSize: 14),
                  children: [
                    TextSpan(
                      text: 'Se connecter',
                      style: TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(_OnboardSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icône — même style sur les 3 slides
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: _primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, color: _primary, size: 56),
          ),
          const SizedBox(height: 40),

          // Titre
          Text(
            slide.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _textDark,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            slide.description,
            style: const TextStyle(
              fontSize: 15,
              color: _textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Extras spécifiques à chaque slide
          if (slide.icon == Icons.flash_on)     _buildStats(),
          if (slide.icon == Icons.swap_horiz_rounded) _buildOperators(),
          if (slide.icon == Icons.shield_outlined)    _buildPills(),
        ],
      ),
    );
  }

  // Slide 1 — stats Lightning
  Widget _buildStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stat('< 1s', 'Confirmation'),
        _divider(),
        _stat('< 1%', 'Frais'),
        _divider(),
        _stat('24/7', 'Disponible'),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value,
          style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900, color: _primary)),
        const SizedBox(height: 2),
        Text(label,
          style: const TextStyle(fontSize: 11, color: _textSecondary)),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1, height: 32,
      color: _border,
      margin: const EdgeInsets.symmetric(horizontal: 24),
    );
  }

  // Slide 2 — badges opérateurs (couleurs de marque intentionnelles)
  Widget _buildOperators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _operatorBadge('MTN', const Color(0xFFFFCB05), Colors.black),
        const SizedBox(width: 12),
        _operatorBadge('MOV', const Color(0xFF0052A5), Colors.white),
        const SizedBox(width: 12),
        _operatorBadge('CEL', const Color(0xFFE30613), Colors.white),
      ],
    );
  }

  Widget _operatorBadge(String name, Color bg, Color textColor) {
    return Container(
      width: 64, height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(name,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          )),
      ),
    );
  }

  // Slide 3 — pills features
  Widget _buildPills() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _Pill('Lightning Network'),
        _Pill('Zéro paperasse'),
        _Pill('Disponible 24h/24'),
      ],
    );
  }
}

// ── Pill statique ─────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  const _Pill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1C28F0), width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C28F0),
        ),
      ),
    );
  }
}

// ── Modèle slide ──────────────────────────────────────────────────────────────

class _OnboardSlide {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardSlide({
    required this.icon,
    required this.title,
    required this.description,
  });
}
