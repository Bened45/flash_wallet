# Flash Wallet

> Bitcoin Lightning payments for West Africa — bridging the Lightning Network with Mobile Money (MTN MoMo, Moov Money, Celtiis).

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Bitcoin](https://img.shields.io/badge/Bitcoin-Lightning-F7931A?logo=bitcoin)](https://lightning.network)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

---

## Table of Contents

1. [Quick Setup](#quick-setup)
2. [Overview](#overview)
3. [Key Features](#key-features)
4. [Architecture](#architecture)
5. [Auto-Convert Flow](#auto-convert-flow)
6. [Tech Stack](#tech-stack)
7. [Project Structure](#project-structure)
8. [Getting Started](#getting-started)
9. [Flash API Integration](#flash-api-integration)
10. [Lightning Network Integration](#lightning-network-integration)
11. [Display Currencies](#display-currencies)
12. [Operator Configuration](#operator-configuration)
13. [Testing](#testing)
14. [Production Deployment](#production-deployment)
15. [Contributing](#contributing)
16. [Roadmap](#roadmap)
17. [License](#license)
18. [Author](#author)

---

## Quick Setup

Get from zero to running in under 5 minutes.

### Prerequisites

- [Flutter SDK 3.10+](https://docs.flutter.dev/get-started/install)
- [Polar](https://lightningpolar.com) — local Lightning Network simulator
- Android device or emulator

### Steps

**1. Install Polar and import the Flash network**

Download and install [Polar](https://lightningpolar.com). If a `flash-network.polar` file is provided in this repo, import it directly:

```
Polar → File → Import Network → select flash-network.polar
```

Otherwise, create a new network manually:
- Add 2 LND nodes (e.g. Alice and Bob)
- Start the network
- Fund Alice's on-chain wallet and open a channel to Bob

**2. Clone the repository**

```bash
git clone https://github.com/Bened45/flash_wallet.git
cd flash_wallet
```

**3. Run the setup script**

```bash
chmod +x setup.sh
./setup.sh
```

The script will:
- Check that Flutter, ADB, and `xxd` are installed
- Auto-detect your local IP address
- Update `lnd_service.dart` and `polar_config.dart` with your IP
- Update `android/app/src/main/res/xml/network_security_config.xml`
- Encode your LND macaroon to hex and inject it into `polar_config.dart`
- Run `flutter pub get`
- Open your firewall port if needed (Linux/Fedora/Ubuntu)

**4. Run the app**

```bash
flutter run
```

Watch for `[LND] ✅` in the logs — that confirms the node connection is live.

> **Manual config**: If you prefer not to use the script, copy
> `lib/core/constants/config.example.dart` to `lib/core/constants/config.dart`
> and fill in the values manually.

---

## Overview

Flash Wallet is a mobile Bitcoin wallet built with Flutter, designed specifically for users in francophone West Africa (Benin, Togo, Cote d'Ivoire, Senegal). It bridges the gap between the global Bitcoin Lightning Network and local Mobile Money systems, enabling:

- **Instant Bitcoin payments** via Lightning Network (sub-second, near-zero fees)
- **Buy Bitcoin** using Mobile Money (MTN MoMo, Moov Money, Celtiis) starting from as little as 100 XOF
- **Sell Bitcoin** and receive CFA francs directly to your mobile wallet
- **Auto-convert** incoming Lightning payments to Mobile Money automatically
- **Multi-currency display** in XOF, EUR, USD, or satoshis

Flash Wallet targets the unbanked and underbanked population of West Africa, offering a fast, secure, and accessible gateway to the Bitcoin economy. The app uses the Flash API (bitcoinflash.xyz) as the fiat on/off-ramp layer and connects to a Lightning Network node via LND REST API.

---

## Key Features

### Core Wallet
- **Lightning Address**: Every user gets a `username@bitcoinflash.xyz` address for receiving payments
- **Real-time balance**: Satoshi balance fetched from LND node, refreshed on demand
- **Transaction history**: View incoming and outgoing Lightning payments
- **BOLT11 Invoices**: Create payment requests with custom amounts and memos
- **QR Code display**: Scannable QR for both Lightning Address and BOLT11 invoices
- **Copy & Share**: One-tap copy or share payment details

### Buy & Sell
- **Buy Bitcoin**: Top up your Lightning wallet using Mobile Money
  - Supports MTN MoMo, Moov Money, Celtiis
  - Minimum: 100 XOF
  - Rate displayed before confirmation
- **Sell Bitcoin**: Convert sats to XOF sent to your Mobile Money number
  - Automatic Flash invoice generation
  - LND pays invoice, Mobile Money disbursement triggered
  - Supports same 3 operators

### Auto-Convert
- **Background polling**: Checks for new incoming payments every 30 seconds
- **Automatic sell trigger**: Detects new paid invoices and converts to XOF automatically
- **Configurable**: Enable/disable per session, persisted across restarts
- **Smart deduplication**: Tracks seen payment hashes to avoid double processing

### Multi-Currency Display
- **XOF** (Franc CFA — default): Using live rate from Flash API
- **EUR**: Derived from fixed peg 655.957 XOF/EUR (official CFA peg)
- **USD**: Live rate via CoinGecko API (BTC/USD)
- **Satoshis**: Raw satoshi display

### Security
- JWT authentication stored in FlutterSecureStorage (encrypted)
- Self-signed TLS support for development (Android network security config)
- Macaroon-based LND authentication (hex-encoded, never logged in full)

---

## Architecture

Flash Wallet follows a feature-first architecture with Riverpod for state management.

```
+------------------------------------------------------------------+
|                        Flash Wallet App                          |
|                                                                  |
|  +-------------+  +-------------+  +-------------+             |
|  |   Auth      |  |  Dashboard  |  |   Convert   |             |
|  |  Feature    |  |   Feature   |  |   Feature   |             |
|  +------+------+  +------+------+  +------+------+             |
|         |                |                |                      |
|  +------+------------------------------------------+--------+  |
|  |                    Shared Services (Riverpod)             |  |
|  |  +-------------+  +-------------+  +----------------+    |  |
|  |  | AuthProvider|  | LndService  |  | WalletProvider |    |  |
|  |  | (JWT, user) |  | (LND REST)  |  | (Flash API)    |    |  |
|  |  +-------------+  +-------------+  +----------------+    |  |
|  |  +-------------+  +-------------+  +----------------+    |  |
|  |  | AutoConvert |  | Currency    |  | FlashApiService|    |  |
|  |  | Service     |  | Provider    |  | (buy/sell/rate)|    |  |
|  |  +-------------+  +-------------+  +----------------+    |  |
|  +-----------------------------------------------------------+  |
|                                                                  |
|  +-----------------------------------------------------------+  |
|  |                      External Services                    |  |
|  |  +--------------+  +--------------+  +---------------+   |  |
|  |  |  Flash API   |  |  LND Node    |  | CoinGecko API |   |  |
|  |  | bitcoinflash |  | (Lightning   |  | (BTC/USD rate)|   |  |
|  |  | .xyz         |  |  Network)    |  |               |   |  |
|  |  +--------------+  +--------------+  +---------------+   |  |
|  +-----------------------------------------------------------+  |
+------------------------------------------------------------------+
```

### State Management

All state is managed via Riverpod providers:

| Provider | Type | Purpose |
|---|---|---|
| `authProvider` | `StateNotifierProvider` | Authentication state (JWT, user profile) |
| `walletProvider` | `StateNotifierProvider` | Flash API state (rate, transactions) |
| `lndProvider` | `StateNotifierProvider` | LND node state (balance, invoices, payments) |
| `lndBalanceProvider` | `Provider<int>` | Current satoshi balance shortcut |
| `autoConvertProvider` | `StateNotifierProvider` | Auto-convert toggle + polling |
| `currencyProvider` | `StateNotifierProvider` | Display currency selection |
| `formattedBalanceProvider` | `Provider<String>` | Balance formatted in selected currency |

### Navigation

GoRouter with named routes:

```
/welcome           -> WelcomeScreen (onboarding)
/register          -> RegisterScreen
/login             -> LoginScreen
/dashboard         -> DashboardScreen (main)
/receive           -> ReceiveScreen
/send              -> SendScreen
/convert           -> ConvertScreen
/profile           -> ProfileScreen
/operator-settings -> OperatorSettingsScreen
```

---

## Auto-Convert Flow

The auto-convert feature monitors the Lightning node for new incoming payments and automatically converts them to Mobile Money.

```
+------------------------------------------------------------+
|                    Auto-Convert Flow                        |
|                                                             |
|  Timer.periodic(30s)                                        |
|         |                                                   |
|         v                                                   |
|  LND: listInvoices(settled=true)                           |
|         |                                                   |
|         v                                                   |
|  Filter: new payment_hash not in _seenHashes?              |
|         | YES                         | NO                  |
|         v                             v                     |
|  Flash API: BUY_BITCOIN              Skip                  |
|  (get invoice for amount)                                  |
|         |                                                   |
|         v                                                   |
|  Extract invoice from res['invoice']                       |
|         |                                                   |
|         v                                                   |
|  LND: payInvoice(bolt11)                                   |
|         |                                                   |
|         v                                                   |
|  Add hash to _seenHashes                                   |
|  Log: [AUTO] Conversion complete!                          |
+------------------------------------------------------------+
```

**Configuration** (stored in SharedPreferences):
- `auto_convert_enabled` — boolean
- `default_operator` — operator ID (`mtn`, `moov`, `celtiis`)
- `operator_mtn_number` — phone number for MTN
- `operator_moov_number` — phone number for Moov
- `operator_celtiis_number` — phone number for Celtiis
- `operator_mtn_enabled` — whether MTN is active
- (same pattern for other operators)

---

## Tech Stack

| Layer | Technology |
|---|---|
| **UI Framework** | Flutter 3.x (Dart) |
| **State Management** | flutter_riverpod 2.x |
| **Navigation** | go_router |
| **HTTP Client** | dio |
| **Secure Storage** | flutter_secure_storage |
| **Local Preferences** | shared_preferences |
| **QR Code** | qr_flutter |
| **Clipboard/Share** | flutter/services, share_plus |
| **Lightning Node** | LND (Lightning Network Daemon) REST API |
| **Fiat On/Off-Ramp** | Flash API (bitcoinflash.xyz) |
| **BTC/USD Rate** | CoinGecko API |
| **Dev Lightning Network** | Polar (local regtest) |

---

## Project Structure

```
flash_wallet/
+-- android/
|   +-- app/
|       +-- src/main/
|           +-- AndroidManifest.xml          # INTERNET permission, network security config
|           +-- res/xml/
|               +-- network_security_config.xml  # Allow self-signed TLS (dev)
+-- ios/
+-- lib/
|   +-- core/
|   |   +-- constants/
|   |   |   +-- app_constants.dart           # SharedPreferences keys, API endpoints
|   |   |   +-- config.example.dart          # Config template (copy to config.dart)
|   |   +-- router/
|   |       +-- app_router.dart              # GoRouter configuration
|   +-- features/
|   |   +-- auth/
|   |   |   +-- screens/
|   |   |       +-- welcome_screen.dart      # Onboarding slides (3 pages)
|   |   |       +-- register_screen.dart     # Registration form
|   |   |       +-- login_screen.dart        # Login form
|   |   +-- wallet/
|   |   |   +-- screens/
|   |   |       +-- dashboard_screen.dart    # Main wallet view
|   |   +-- send/
|   |   |   +-- screens/
|   |   |       +-- send_screen.dart         # Send Lightning payment
|   |   +-- receive/
|   |   |   +-- screens/
|   |   |       +-- receive_screen.dart      # Receive + invoice creation
|   |   +-- convert/
|   |   |   +-- screens/
|   |   |       +-- convert_screen.dart      # Buy/Sell Bitcoin
|   |   +-- profile/
|   |   |   +-- screens/
|   |   |       +-- profile_screen.dart      # User profile + settings
|   |   +-- settings/
|   |       +-- screens/
|   |           +-- operator_settings_screen.dart  # Mobile Money operator config
|   +-- shared/
|       +-- services/
|           +-- auth_provider.dart           # Auth state + Flash API login/register
|           +-- wallet_provider.dart         # Flash API (transactions, rate)
|           +-- lnd_service.dart             # LND REST API client
|           +-- auto_convert_service.dart    # Background auto-convert polling
|           +-- currency_provider.dart       # Multi-currency display
|           +-- polar_config.dart            # Development LND node config
+-- setup.sh                                 # Automated dev environment setup
+-- pubspec.yaml
+-- README.md
```

---

## Getting Started

### Prerequisites

- Flutter SDK 3.10+ (`flutter --version`)
- Dart SDK 3.0+
- Android Studio or VS Code with Flutter extension
- An Android device or emulator (API 21+)
- (For development) Polar — local Lightning Network simulator

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Bened45/flash_wallet.git
   cd flash_wallet
   ```

2. **Run the automated setup**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

   Or configure manually:

3. **Configure the LND node** (manual)

   Edit `lib/shared/services/polar_config.dart`:
   ```dart
   static const String lndRestUrl = 'https://YOUR_PC_IP:8081';
   static const String macaroonHex = 'YOUR_ADMIN_MACAROON_HEX';
   ```

   To get your macaroon hex from Polar:
   ```bash
   xxd -p ~/.polar/networks/1/volumes/lnd/alice/data/chain/bitcoin/regtest/admin.macaroon | tr -d '\n'
   ```

4. **Open firewall port** (Linux/Fedora)
   ```bash
   sudo firewall-cmd --add-port=8081/tcp --permanent
   sudo firewall-cmd --reload
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

### Environment Configuration

The app targets two environments:

| Environment | API Base | LND Node |
|---|---|---|
| Development | `https://staging.bitcoinflash.xyz` | Polar (local regtest) |
| Production | `https://api.bitcoinflash.xyz` | Production LND node |

Endpoints are defined in `lib/core/constants/app_constants.dart`.

### Android Network Security

For development, the app allows connections to the Polar LND node using a self-signed TLS certificate. This is configured in `android/app/src/main/res/xml/network_security_config.xml` (generated automatically by `setup.sh`):

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">192.168.1.148</domain>
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </domain-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
</network-security-config>
```

**Note**: For production, replace the Polar IP with your production LND node's domain and use a properly signed TLS certificate.

---

## Flash API Integration

Flash Wallet uses the Flash API as the fiat on/off-ramp layer. The API handles:
- User registration and authentication (JWT)
- Mobile Money payment initiation (MTN, Moov, Celtiis)
- BTC/XOF rate fetching
- Transaction history

### Authentication

```
POST /api/auth/register
{
  "username": "string",
  "password": "string",
  "phone": "string"
}

POST /api/auth/login
{
  "username": "string",
  "password": "string"
}
Response: { "token": "JWT_TOKEN", "user": { "lightning_address": "user@bitcoinflash.xyz" } }
```

JWT token is stored in FlutterSecureStorage under the key `jwt_token`.

### Buy Bitcoin (BUY_BITCOIN)

Used when selling sats for XOF (user wants to receive Mobile Money):

```
POST /api/transactions
Authorization: Bearer JWT_TOKEN
{
  "type": "BUY_BITCOIN",
  "amount": 5000,
  "phone": "22991234567",
  "operator": "mtn"
}
Response: { "invoice": "lnbc...", ... }
```

The returned BOLT11 invoice is paid by the LND node. Once paid, Flash triggers the Mobile Money disbursement.

### Sell Bitcoin (SELL_BITCOIN)

Used when buying sats with XOF (user sends Mobile Money, receives Lightning):

```
POST /api/transactions
Authorization: Bearer JWT_TOKEN
{
  "type": "SELL_BITCOIN",
  "amount": 5000,
  "phone": "22991234567",
  "operator": "mtn"
}
Response: { "invoice": "lnbc..." }
```

### Rate Fetching

```
GET /api/rate
Response: { "rate": 3.84 }   // XOF per satoshi
```

The rate is stored in `WalletState.rateXof` and used by `CurrencyState.convert()`.

---

## Lightning Network Integration

Flash Wallet communicates with an LND node via its REST API (port 8081).

### LND REST Endpoints Used

| Operation | Endpoint | Method |
|---|---|---|
| Get balance | `/v1/balance/channels` | GET |
| List invoices | `/v1/invoices?settled=true` | GET |
| Create invoice | `/v1/invoices` | POST |
| Pay invoice | `/v1/channels/transactions` | POST |
| Get info | `/v1/getinfo` | GET |

### Authentication

LND uses macaroon-based authentication. The admin macaroon is passed as a hex string in the `Grpc-Metadata-Macaroon` header:

```dart
options: Options(
  headers: {'Grpc-Metadata-Macaroon': PolarConfig.macaroonHex},
  validateStatus: (s) => s != null && s < 600,
)
```

### TLS

LND uses a self-signed certificate by default. The Dio client bypasses certificate verification in development:

```dart
(_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
  final client = HttpClient();
  client.badCertificateCallback = (cert, host, port) => true;
  return client;
};
```

**This must be disabled in production.** Replace with proper certificate pinning.

### Error Handling

LND returns human-readable errors in the response body:

```json
{ "error": "invoice expired", "code": 2 }
```

`LndService._friendlyLndError()` maps common error codes and messages to user-friendly French strings shown in snackbars.

### Create Invoice Example

```dart
final pr = await ref.read(lndProvider.notifier).createInvoice(amountSats, memo);
// pr = "lnbcrt500u1p..." (BOLT11 invoice string)
```

### Pay Invoice Example

```dart
final success = await ref.read(lndProvider.notifier).payInvoice(bolt11);
// success = true | false
```

---

## Display Currencies

Users can display their balance in four currencies, selected from the Profile screen.

### Currency Conversion Logic

```
XOF  = sats x rateXof          (rateXof from Flash API, ~3.84 XOF/sat)
EUR  = XOF / 655.957            (fixed CFA peg, no API needed)
USD  = sats x usdPerSat         (usdPerSat from CoinGecko)
sats = sats                     (raw value)
```

The XOF/EUR rate of 655.957 is the official fixed parity of the CFA franc, established by the Bretton Woods agreements and maintained by the French Treasury. It never changes without a formal devaluation.

### Persistence

Selected currency is saved to SharedPreferences under key `display_currency` using the currency code (`XOF`, `EUR`, `USD`, `sats`).

### CoinGecko API

USD rate is fetched once on startup and on-demand when USD is selected:

```
GET https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd
Response: { "bitcoin": { "usd": 95000.0 } }
```

`usdPerSat = btcUsd / 100_000_000`

---

## Operator Configuration

The Operator Settings screen (`/operator-settings`) lets users configure their Mobile Money operators.

### Configuration per Operator

Each of the 3 operators (MTN, Moov, Celtiis) has:
- **Enabled toggle** — whether to use this operator
- **Phone number** — the Mobile Money number for payouts
- **Default** — which operator to use for auto-convert

### SharedPreferences Keys

```
default_operator          -> "mtn" | "moov" | "celtiis"
operator_mtn_number       -> "22991234567"
operator_mtn_enabled      -> true | false
operator_moov_number      -> "22961234567"
operator_moov_enabled     -> true | false
operator_celtiis_number   -> "22941234567"
operator_celtiis_enabled  -> true | false
```

For backward compatibility, the default operator's number is also written to:
```
mobile_money_number   -> "22991234567"
operator              -> "mtn"
```

These legacy keys are read by `AutoConvertService.getSettings()` as a fallback.

### Validation

Before saving, the screen validates:
1. The default operator must be enabled
2. The default operator must have a non-empty phone number
3. Phone number must be numeric

---

## Testing

### Development Setup with Polar

[Polar](https://lightningpolar.com) is used to simulate a local Lightning Network for development.

1. Install Polar
2. Create a new network with at least 2 LND nodes
3. Fund Alice's node and open a channel to Bob
4. Get Alice's REST port (usually 8081)
5. Run `./setup.sh` — it will find the macaroon automatically

### Running Tests

```bash
# Unit tests
flutter test

# Integration tests (requires connected device)
flutter test integration_test/

# Widget tests
flutter test test/widget_test.dart
```

### Debug Logging

The app uses prefixed debug logs for easy filtering:

| Prefix | Service |
|---|---|
| `[LND]` | LND node operations |
| `[AUTO]` | Auto-convert service |
| `[FLASH]` | Flash API calls |
| `[CURRENCY]` | Currency rate fetching |
| `[AUTH]` | Authentication events |

Filter in Android Studio logcat or with `flutter logs`:
```bash
flutter logs | grep -E '\[LND\]|\[AUTO\]|\[FLASH\]'
```

---

## Production Deployment

### Android Build

1. **Generate signing key** (if not already done):
   ```bash
   keytool -genkey -v -keystore ~/flash-wallet-key.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias flash-wallet
   ```

2. **Configure signing** in `android/key.properties`:
   ```
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=flash-wallet
   storeFile=/home/user/flash-wallet-key.jks
   ```

3. **Update `android/app/build.gradle`** to reference key.properties.

4. **Switch to production API**:
   - Update `AppConstants.baseUrl` to `https://api.bitcoinflash.xyz`
   - Replace Polar LND config with production node config
   - Remove self-signed TLS bypass

5. **Build release APK**:
   ```bash
   flutter build apk --release
   # Output: build/app/outputs/flutter-apk/app-release.apk
   ```

6. **Build App Bundle (Play Store)**:
   ```bash
   flutter build appbundle --release
   ```

### iOS Build

```bash
flutter build ios --release
# Then open Xcode and archive
```

### Production Checklist

- [ ] Remove Polar/dev LND configuration
- [ ] Disable TLS certificate bypass (`badCertificateCallback`)
- [ ] Switch to production Flash API endpoint
- [ ] Enable ProGuard/R8 code minification
- [ ] Update `android:networkSecurityConfig` for production domains
- [ ] Test on real devices with real Mobile Money accounts
- [ ] Verify CoinGecko rate fetching works (rate limits: 10-30 calls/min free tier)
- [ ] Add error monitoring (Sentry, Firebase Crashlytics)
- [ ] Configure push notifications for payment received events
- [ ] Remove `config.dart` from version control (already in `.gitignore`)

---

## Contributing

Contributions are welcome! Please follow these guidelines.

### Development Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes
4. Test thoroughly on a real device
5. Submit a pull request with a clear description

### Code Style

- Follow Flutter/Dart official style guide
- Use Riverpod for all state management
- Keep screens lean — extract business logic to service classes
- Comment only non-obvious logic (the WHY, not the WHAT)
- Use Flash color palette strictly:
  - Primary: `#1C28F0`
  - Primary Light: `#EEF0FF`
  - Dark Text: `#0A0A2E`
  - Secondary Text: `#8888AA`
  - Border: `#E8E8F4`
  - Success: `#00B96B`

### Commit Convention

```
feat: add operator settings screen
fix: correct LND invoice extraction field
refactor: extract currency conversion to provider
docs: update README with quick setup section
```

---

## Roadmap

### v1.0 — MVP (Current)
- [x] User registration and authentication
- [x] Lightning balance display
- [x] Receive payments (Lightning Address + BOLT11)
- [x] Send payments
- [x] Buy Bitcoin via Mobile Money
- [x] Sell Bitcoin to Mobile Money
- [x] Auto-convert incoming payments
- [x] Multi-currency display (XOF/EUR/USD/sats)
- [x] Operator configuration per number
- [x] Automated dev setup script

### v1.1 — UX Improvements
- [ ] Biometric authentication (fingerprint/face)
- [ ] Transaction history with filtering
- [ ] Push notifications for received payments
- [ ] Dark mode
- [ ] PIN code lock

### v1.2 — Expanded Coverage
- [ ] Support for Senegal (Orange Money, Wave)
- [ ] Support for Cote d'Ivoire (Orange CI, MTN CI)
- [ ] Support for Togo (Flooz, T-Money)
- [ ] LNURL-pay / LNURL-withdraw support
- [ ] Lightning Address sending (pay other @domain addresses)

### v2.0 — Advanced Features
- [ ] On-chain Bitcoin support
- [ ] Hardware wallet integration (Trezor, Ledger)
- [ ] Multi-node support
- [ ] Merchant POS mode
- [ ] NFC tap-to-pay

---

## License

MIT License

Copyright (c) 2026 Beni EDAYE

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

---

## Author

**Beni EDAYE**

Bitcoin and Lightning Network developer based in Benin, West Africa.
Member of Plan B Network — contributing to Bitcoin adoption in francophone Africa.

- GitHub: [@Bened45](https://github.com/Bened45)
- Country: Benin
- Network: Plan B Network 2026

---

*Flash Wallet — Making Bitcoin accessible to every West African, one sat at a time.*
