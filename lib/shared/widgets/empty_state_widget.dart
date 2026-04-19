import 'package:flutter/material.dart';

/// Variants dédiés pour chaque contexte.
enum EmptyStateType { transactions, contacts, notifications, generic }

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.type,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final EmptyStateType type;
  final String? title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final config = _configFor(type);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8F4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon circle
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: config.bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(config.icon, size: 32, color: config.iconColor),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            title ?? config.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A0A2E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          // Subtitle
          Text(
            subtitle ?? config.subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8888AA),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          // Optional CTA
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C28F0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _EmptyConfig _configFor(EmptyStateType t) {
    switch (t) {
      case EmptyStateType.transactions:
        return const _EmptyConfig(
          icon: Icons.receipt_long_outlined,
          bgColor: Color(0xFFEEF0FF),
          iconColor: Color(0xFF1C28F0),
          title: 'Aucune transaction',
          subtitle: 'Vos paiements Lightning et conversions\napparaîtront ici.',
        );
      case EmptyStateType.contacts:
        return const _EmptyConfig(
          icon: Icons.people_outline,
          bgColor: Color(0xFFF0FFF8),
          iconColor: Color(0xFF00B96B),
          title: 'Aucun contact récent',
          subtitle: 'Les destinataires de vos envois\ns\'afficheront ici pour un accès rapide.',
        );
      case EmptyStateType.notifications:
        return const _EmptyConfig(
          icon: Icons.notifications_none_outlined,
          bgColor: Color(0xFFFFF8E1),
          iconColor: Color(0xFFFFA000),
          title: 'Aucune notification',
          subtitle: 'Vous serez notifié lors de\npaiements reçus ou convertis.',
        );
      case EmptyStateType.generic:
        return const _EmptyConfig(
          icon: Icons.inbox_outlined,
          bgColor: Color(0xFFF5F5FA),
          iconColor: Color(0xFF8888AA),
          title: 'Rien ici pour l\'instant',
          subtitle: 'Les données s\'afficheront ici.',
        );
    }
  }
}

class _EmptyConfig {
  const _EmptyConfig({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
}
