# CLAUDE.md — AI-Assisted Development

This file documents the use of Claude (Anthropic) as the primary development partner on Flash Wallet.

---

## Overview

Flash Wallet was designed and implemented in close collaboration with Claude, used at two complementary levels: Claude.ai for architecture and planning, and Claude Code for implementation and terminal debugging.

---

## Claude.ai — Architecture & Planning

Claude.ai was used to:

- Analyze the Plan B Network brief and define the technical architecture (LND + Flash API vs Breez SDK alone)
- Understand the Lightning Address protocol and LNURL-pay spec
- Design the auto-convert flow (polling vs webhooks)
- Debug Flash API integration errors (field `invoice` vs `transaction.lightning_invoice`)
- Write documentation (README, DELIVERABLE, CLAUDE.md)
- Reason through technical trade-offs (custodial vs non-custodial, regtest vs mainnet)

---

## Claude Code — Implementation

Claude Code (interactive terminal agent) was used for direct implementation inside the codebase.

### Problems Solved

| Problem | Solution |
|---|---|
| Breez SDK Spark Flutter build conflict | Pivoted to LND REST API + Polar |
| `No route to host errno 113` on Android | Wrong IP + missing INTERNET permission in AndroidManifest |
| Macaroon unreadable on real device | Fallback to `PolarConfig.macaroonHex` when `dart:io` unavailable |
| LND 500 error unreadable in UI | `_friendlyLndError()` with human-readable French messages |
| Wrong Flash API invoice field | `res['invoice']` instead of `res['transaction']['lightning_invoice']` |
| Auto-convert running silently | Full `[AUTO]` logging + phone number fallback from SharedPreferences |
| Inconsistent onboarding colors | Single `#1C28F0` palette enforced across all slides |
| Duplicate address on Receive screen | Removed redundant Polar address block |

### Files Created or Modified with Claude Code

```
lib/shared/services/lnd_service.dart               — full LND REST client
lib/shared/services/auto_convert_service.dart      — polling + auto-conversion
lib/shared/services/currency_provider.dart         — multi-currency (XOF/EUR/USD/sats)
lib/shared/services/polar_config.dart              — dev LND config
lib/features/settings/screens/
  operator_settings_screen.dart                    — Mobile Money operator config
lib/features/wallet/screens/dashboard_screen.dart  — LND indicator, multi-currency balance
lib/features/convert/screens/convert_screen.dart   — wired to real services
lib/features/receive/screens/receive_screen.dart   — single address, no Polar duplicate
lib/features/auth/screens/welcome_screen.dart      — unified onboarding palette
lib/features/profile/screens/profile_screen.dart   — currency picker + operator settings
android/app/src/main/AndroidManifest.xml           — INTERNET permission
android/app/src/main/res/xml/
  network_security_config.xml                      — Polar self-signed TLS
lib/core/constants/config.example.dart             — configuration template
setup.sh                                           — automated setup script
README.md                                          — full documentation (838 lines)
```

---

## Key Technical Decisions (made with Claude)

### LND + Flash API Architecture

**Decision**: Use LND REST API (via Polar in dev) + Flash API (fiat on/off-ramp) rather than Breez SDK alone.

**Reason**: Breez SDK Spark had irreconcilable build conflicts with the target Flutter version. LND REST is more direct, better documented, and Polar provides a reliable local test environment.

### 30-second Polling

**Decision**: `Timer.periodic(30s)` for auto-convert, no webhooks.

**Reason**: The Flash API does not support outbound server-side webhooks. Client-side polling is the only viable option on a mobile app.

### Fixed XOF/EUR Rate

**Decision**: 655.957 XOF/EUR hardcoded, no API call.

**Reason**: This is the official fixed parity of the CFA franc (revised Bretton Woods agreement), maintained by the French Treasury. It never changes without a formal devaluation — calling an API for it would be pointless.

### `response['invoice']` Key

**Decision**: Extract the Lightning invoice from `res['invoice']` at the root of the Flash API response.

**Reason**: Discovered by analyzing the real API response with the developer. The `transaction.lightning_invoice` field does not exist in the actual response.

### Regtest Polar for Testing

**Decision**: Polar (local regtest network) in development, mainnet LND in production.

**Reason**: Allows testing real Lightning payments without any risk of fund loss. Regtest invoices are indistinguishable from mainnet invoices at the code level.

---

## Agent Skills Used

- `Read` — read source files to understand context before making changes
- `Edit` — targeted modifications (old_string / new_string) without full rewrites
- `Write` — create new files
- `Bash` — Flutter compilation, network diagnostics (`curl`, `xxd`), firewall management
- `Grep` / `Glob` — codebase search
- `Agent (Explore)` — broad codebase exploration

---

## Workflow

```
Claude.ai
  └── Architecture, protocols, trade-offs, documentation

Claude Code (terminal)
  └── Read existing code
  └── Precise file-by-file modifications
  └── Compile and verify errors
  └── Debug with real-time logs

Developer (Béni EDAYE)
  └── Testing on real devices (STK L22, SM-A105G)
  └── Mobile Money flow validation (MTN MoMo Benin)
  └── Product decisions (UX, operators, currencies)
  └── Flash API staging account integration
```

---

## Model Used

- **Claude Sonnet 4.6** via Claude Code CLI
- Context: long working sessions with automatic compaction
- Persistent memory: `/home/d/.claude/projects/-home-d-Projects-flash-wallet/memory/`
