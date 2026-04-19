import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/wallet/screens/dashboard_screen.dart';
import '../../features/receive/screens/receive_screen.dart';
import '../../features/send/screens/send_screen.dart';
import '../../features/convert/screens/convert_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/wallet/screens/confirmation_screens.dart';
import '../../features/wallet/screens/history_screen.dart';
import '../../shared/models/transaction.dart';

class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';
  static const String dashboard = '/dashboard';
  static const String receive = '/receive';
  static const String send = '/send';
  static const String convert = '/convert';
  static const String profile = '/profile';
  static const String receiveConfirm = '/receive-confirm';
  static const String sendConfirm = '/send-confirm';
  static const String convertConfirm = '/convert-confirm';
  static const String history = '/history';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) {
          final extra = state.extra as Map<String, String>;
          return OtpScreen(
            email: extra['email']!,
            userId: extra['userId']!,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.receiveConfirm,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ReceiveConfirmScreen(
            transaction: extra['transaction'] as Transaction,
            senderName: extra['senderName'] as String?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.sendConfirm,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return SendConfirmScreen(
            transaction: extra['transaction'] as Transaction,
            receiverName: extra['receiverName'] as String?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.convertConfirm,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ConvertConfirmScreen(
            isSell: extra['isSell'] as bool? ?? true,
            transaction: extra['transaction'] as Transaction?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) => const HistoryScreen(),
      ),


      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.receive,
            builder: (context, state) => const ReceiveScreen(),
          ),
          GoRoute(
            path: AppRoutes.send,
            builder: (context, state) => const SendScreen(),
          ),
          GoRoute(
            path: AppRoutes.convert,
            builder: (context, state) => const ConvertScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getCurrentIndex(context),
        onTap: (index) => _onTap(context, index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1C28F0),
        unselectedItemColor: const Color(0xFFCCCCDD),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.arrow_downward_outlined),
            activeIcon: Icon(Icons.arrow_downward),
            label: 'Recevoir',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.arrow_upward_outlined),
            activeIcon: Icon(Icons.arrow_upward),
            label: 'Envoyer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_outlined),
            activeIcon: Icon(Icons.swap_horiz),
            label: 'Convertir',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    switch (location) {
      case AppRoutes.dashboard:
        return 0;
      case AppRoutes.receive:
        return 1;
      case AppRoutes.send:
        return 2;
      case AppRoutes.convert:
        return 3;
      case AppRoutes.profile:
        return 4;
      default:
        return 0;
    }
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.dashboard);
        break;
      case 1:
        context.go(AppRoutes.receive);
        break;
      case 2:
        context.go(AppRoutes.send);
        break;
      case 3:
        context.go(AppRoutes.convert);
        break;
      case 4:
        context.go(AppRoutes.profile);
        break;
    }
  }
}