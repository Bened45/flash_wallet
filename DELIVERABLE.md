# Flash Wallet — Deliverables
Plan B Network 2026 — Dev Track

---

## GitHub Repository

https://github.com/Bened45/flash_wallet

## Demo Video

[To be completed after recording]

---

## Project Overview

Flash Wallet is a Bitcoin Lightning wallet for francophone West Africa (Benin, Togo, Côte d'Ivoire, Senegal). It enables sending and receiving sats over the Lightning Network, and automatically converting between Bitcoin and Mobile Money (MTN MoMo, Moov Money, Celtiis) in seconds.

**Problem solved**: West African populations have no practical access to traditional Bitcoin exchanges. Flash Wallet creates a direct bridge between the Lightning Network and the Mobile Money systems already massively adopted in the region — no bank account required, starting from 100 XOF.

---

## Axis 1 — Lightning Wallet (Flutter)

- **Repo**: https://github.com/Bened45/flash_wallet
- **Stack**: Flutter 3.x, Riverpod, LND REST API, Flash API (bitcoinflash.xyz)
- **Platform**: Android (iOS compatible)

### Implemented Features

| Feature | Status |
|---|---|
| Authentication (register/login JWT) | Done |
| Dashboard with real-time Lightning balance | Done |
| Receive — Lightning Address + BOLT11 invoice | Done |
| Send — BOLT11 payment via LND | Done |
| Buy sats — Mobile Money → Lightning | Done |
| Sell sats — Lightning → Mobile Money | Done |
| Auto-convert — background automatic conversion | Done |
| Multi-currency display — XOF / EUR / USD / sats | Done |
| Mobile Money operator configuration | Done |
| 3-slide onboarding | Done |
| Automated setup script (`setup.sh`) | Done |

### Architecture

```
Flutter App
  └── Riverpod Providers
        ├── AuthProvider       → Flash API (JWT)
        ├── LndService         → LND REST API (Polar in dev)
        ├── WalletProvider     → Flash API (rate, transactions)
        ├── AutoConvertService → 30s Timer + LND + Flash API
        └── CurrencyProvider   → CoinGecko + fixed CFA peg
```

---

## Axis 3 — Onboarding

3 onboarding slides built into the Flutter wallet:

1. **Bitcoin in seconds** — Lightning stats (< 1s confirmation, < 1% fees, 24/7)
2. **Convert to XOF** — MTN / Moov / Celtiis operator badges
3. **Reliable payments** — Lightning Network, zero paperwork, available 24/7

---

## Flash Network (Polar)

- **Network file**: `polar/flash-network.zip`
- **Import instructions**: see `README.md` — Quick Setup section
- **Alice node**: LND (regtest), REST port 8081
- **Channel**: Alice ↔ Bob, 1,000,000 sats capacity

---

## Resources

- Flash API Docs: https://docs.bitcoinflash.xyz
- Lightning Address spec: https://lightningaddress.com
- Polar (dev network): https://lightningpolar.com
- Plan B Network: https://planb.network
- LND REST API: https://lightning.engineering/api-docs/api/lnd/

---

## Author

Béni EDAYE — Benin
Plan B Network 2026
GitHub: https://github.com/Bened45
