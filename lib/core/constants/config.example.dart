// ═══════════════════════════════════════════════════════════════════════════
// Flash Wallet — Configuration Template
//
// INSTRUCTIONS :
//   1. Copiez ce fichier : cp config.example.dart config.dart
//   2. Remplissez toutes les valeurs marquées TODO
//   3. Ne commitez JAMAIS config.dart (ajouté dans .gitignore)
//
// Alternative : lancez ./setup.sh à la racine du projet pour configurer
//               automatiquement tous ces paramètres.
// ═══════════════════════════════════════════════════════════════════════════

class FlashConfig {

  // ── Nœud Lightning (LND) ──────────────────────────────────────────────────

  /// IP ou hostname de votre nœud LND.
  /// Polar sur la même machine (émulateur Android) : 10.0.2.2
  /// Polar sur la même machine (vrai appareil)     : votre IP locale, ex: 192.168.1.100
  /// Production                                     : votre domaine LND
  static const String lndHost = 'VOTRE_IP_ICI'; // TODO

  /// Port REST de LND (défaut Polar : 8081)
  static const String lndPort = '8081';

  /// URL complète construite automatiquement
  static const String lndRestUrl = 'https://$lndHost:$lndPort';

  /// Chemin vers le fichier admin.macaroon sur votre machine de développement.
  /// Polar standard Linux : ~/.polar/networks/1/volumes/lnd/alice/data/chain/bitcoin/regtest/admin.macaroon
  /// Polar standard macOS : ~/Library/Application Support/polar/networks/1/...
  /// Polar standard Win   : %APPDATA%\polar\networks\1\...
  ///
  /// Ce chemin n'est utilisé que sur desktop. Sur Android, [lndMacaroonHex] est utilisé.
  static const String lndMacaroonPath = 'CHEMIN_MACAROON_ICI'; // TODO

  /// Macaroon encodé en hex.
  /// Obtenez-le via : xxd -p admin.macaroon | tr -d '\n'
  /// Ou depuis Polar : clic sur le nœud → onglet Connect → Macaroon (HEX)
  static const String lndMacaroonHex = 'VOTRE_MACAROON_HEX_ICI'; // TODO

  // ── Flash API ─────────────────────────────────────────────────────────────

  /// URL de base de l'API Flash.
  /// Développement : https://staging.bitcoinflash.xyz/api/v1
  /// Production    : https://api.bitcoinflash.xyz/api/v1
  static const String flashBaseUrl = 'https://staging.bitcoinflash.xyz/api/v1'; // TODO: changer en prod

  // ── Timeouts réseau ───────────────────────────────────────────────────────

  /// Timeout de connexion en secondes
  static const int connectTimeoutSeconds = 10;

  /// Timeout de réception en secondes
  static const int receiveTimeoutSeconds = 15;

  // ── Auto-Convert ──────────────────────────────────────────────────────────

  /// Intervalle de polling en secondes (défaut : 30)
  static const int pollingIntervalSeconds = 30;

  /// Seuil minimum en XOF pour déclencher une conversion automatique
  static const int autoConvertMinXof = 100;

  // ── Développement ────────────────────────────────────────────────────────

  /// Mettre à true pour activer les logs détaillés dans la console
  static const bool verboseLogs = true; // TODO: false en production

  /// Mettre à true pour contourner la vérification TLS (développement uniquement)
  /// ATTENTION : ne jamais mettre true en production
  static const bool allowSelfSignedTls = true; // TODO: false en production
}
