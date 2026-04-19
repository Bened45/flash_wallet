#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Flash Wallet — Setup Script
# Configure l'environnement de développement complet en quelques minutes.
# Usage: chmod +x setup.sh && ./setup.sh
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# ── Couleurs ──────────────────────────────────────────────────────────────────
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERR]${NC}  $1"; }
step()    { echo -e "\n${BOLD}${CYAN}▶ $1${NC}"; }
divider() { echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"; }

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${BLUE}"
cat << 'EOF'
  ███████╗██╗      █████╗ ███████╗██╗  ██╗
  ██╔════╝██║     ██╔══██╗██╔════╝██║  ██║
  █████╗  ██║     ███████║███████╗███████║
  ██╔══╝  ██║     ██╔══██║╚════██║██╔══██║
  ██║     ███████╗██║  ██║███████║██║  ██║
  ╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
  WALLET — Bitcoin Lightning pour l'Afrique de l'Ouest
EOF
echo -e "${NC}"
divider
echo -e "  Script de configuration de l'environnement de développement"
echo -e "  Auteur : Béni EDAYE — Plan B Network 2026"
divider
echo ""

# ── Variables globales ────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LND_SERVICE="$SCRIPT_DIR/lib/shared/services/lnd_service.dart"
POLAR_CONFIG="$SCRIPT_DIR/lib/shared/services/polar_config.dart"
NETWORK_SEC="$SCRIPT_DIR/android/app/src/main/res/xml/network_security_config.xml"

# ══════════════════════════════════════════════════════════════════════════════
# ÉTAPE 1 — Vérification des prérequis
# ══════════════════════════════════════════════════════════════════════════════
step "Étape 1/7 — Vérification des prérequis"

# Flutter
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -1 | awk '{print $2}')
    success "Flutter trouvé : v${FLUTTER_VERSION}"
else
    error "Flutter n'est pas installé ou absent du PATH."
    echo -e "  Installez Flutter : ${CYAN}https://docs.flutter.dev/get-started/install${NC}"
    exit 1
fi

# Dart
if command -v dart &> /dev/null; then
    DART_VERSION=$(dart --version 2>&1 | awk '{print $4}')
    success "Dart trouvé : v${DART_VERSION}"
else
    error "Dart non trouvé. Il est normalement inclus avec Flutter."
    exit 1
fi

# ADB (Android Debug Bridge)
if command -v adb &> /dev/null; then
    success "ADB trouvé : $(adb version 2>/dev/null | head -1)"
    # Lister les appareils connectés
    DEVICES=$(adb devices 2>/dev/null | grep -v "List of devices" | grep -v "^$" | grep -c "device" || true)
    if [ "$DEVICES" -gt 0 ]; then
        success "$DEVICES appareil(s) Android connecté(s)"
    else
        warn "Aucun appareil Android connecté. Connectez votre appareil ou lancez un émulateur."
    fi
else
    warn "ADB non trouvé. Installez Android SDK Platform Tools."
    echo -e "  ${CYAN}https://developer.android.com/tools/releases/platform-tools${NC}"
fi

# xxd (pour encoder le macaroon en hex)
if command -v xxd &> /dev/null; then
    success "xxd trouvé (encodage macaroon)"
else
    error "xxd non trouvé. Installez-le : sudo apt install xxd (Debian/Ubuntu) ou sudo dnf install vim-common (Fedora)"
    exit 1
fi

# Polar (optionnel — non bloquant)
if command -v polar &> /dev/null; then
    success "Polar trouvé"
elif [ -f "$HOME/Applications/Polar.AppImage" ] || [ -f "/usr/local/bin/polar" ] || \
     ls "$HOME"/.local/share/applications/polar*.desktop 2>/dev/null | head -1 | grep -q polar; then
    success "Polar détecté"
else
    warn "Polar non trouvé dans le PATH. Assurez-vous qu'il est installé et que votre réseau Lightning est actif."
    echo -e "  Téléchargez Polar : ${CYAN}https://lightningpolar.com${NC}"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# ÉTAPE 2 — IP locale du PC
# ══════════════════════════════════════════════════════════════════════════════
step "Étape 2/7 — Adresse IP locale"

# Auto-détection de l'IP locale
DETECTED_IP=""
if command -v ip &> /dev/null; then
    DETECTED_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1)
elif command -v hostname &> /dev/null; then
    DETECTED_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

if [ -n "$DETECTED_IP" ]; then
    info "IP détectée automatiquement : ${BOLD}$DETECTED_IP${NC}"
    read -rp "$(echo -e "  Utiliser ${CYAN}$DETECTED_IP${NC} ? [O/n] : ")" USE_DETECTED
    if [[ "$USE_DETECTED" =~ ^[Nn]$ ]]; then
        read -rp "  Entrez votre IP locale (ex: 192.168.1.100) : " LOCAL_IP
    else
        LOCAL_IP="$DETECTED_IP"
    fi
else
    warn "Impossible de détecter l'IP automatiquement."
    read -rp "  Entrez votre IP locale (ex: 192.168.1.100) : " LOCAL_IP
fi

# Validation basique du format IP
if ! echo "$LOCAL_IP" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
    error "Format d'IP invalide : $LOCAL_IP"
    exit 1
fi

success "IP configurée : $LOCAL_IP"

# Port LND
read -rp "  Port REST LND (défaut : 8081) : " LND_PORT
LND_PORT=${LND_PORT:-8081}
success "Port LND : $LND_PORT"

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# ÉTAPE 3 — Injection de l'IP dans lnd_service.dart
# ══════════════════════════════════════════════════════════════════════════════
step "Étape 3/7 — Mise à jour de lnd_service.dart"

if [ ! -f "$LND_SERVICE" ]; then
    error "Fichier introuvable : $LND_SERVICE"
    exit 1
fi

# Remplacer l'IP dans _baseUrl
OLD_URL=$(grep "_baseUrl" "$LND_SERVICE" | grep -oP "https://[^'\"]+")
if [ -n "$OLD_URL" ]; then
    sed -i "s|static const String _baseUrl = 'https://[^']*';|static const String _baseUrl = 'https://$LOCAL_IP:$LND_PORT';|g" "$LND_SERVICE"
    success "lnd_service.dart : $OLD_URL → https://$LOCAL_IP:$LND_PORT"
else
    warn "Pattern _baseUrl non trouvé dans lnd_service.dart, vérifiez manuellement."
fi

# Mettre à jour polar_config.dart aussi
if [ -f "$POLAR_CONFIG" ]; then
    OLD_POLAR=$(grep "lndRestUrl" "$POLAR_CONFIG" | grep -oP "https://[^'\"]+")
    sed -i "s|static const String lndRestUrl = 'https://[^']*';|static const String lndRestUrl = 'https://$LOCAL_IP:$LND_PORT';|g" "$POLAR_CONFIG"
    success "polar_config.dart : ${OLD_POLAR:-ancien} → https://$LOCAL_IP:$LND_PORT"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# ÉTAPE 4 — Android network_security_config.xml
# ══════════════════════════════════════════════════════════════════════════════
step "Étape 4/7 — Android network security config"

mkdir -p "$(dirname "$NETWORK_SEC")"

cat > "$NETWORK_SEC" << XMLEOF
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- LND dev node — self-signed TLS certificate -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">$LOCAL_IP</domain>
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </domain-config>
    <!-- Default: only system-trusted CAs for production endpoints -->
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
</network-security-config>
XMLEOF

success "network_security_config.xml mis à jour pour $LOCAL_IP"

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# ÉTAPE 5 — Macaroon LND
# ══════════════════════════════════════════════════════════════════════════════
step "Étape 5/7 — Macaroon LND (authentification)"

DEFAULT_MACAROON_PATH="$HOME/.polar/networks/1/volumes/lnd/alice/data/chain/bitcoin/regtest/admin.macaroon"

if [ -f "$DEFAULT_MACAROON_PATH" ]; then
    info "Macaroon Polar détecté : $DEFAULT_MACAROON_PATH"
    read -rp "$(echo -e "  Utiliser ce fichier ? [O/n] : ")" USE_DEFAULT_MAC
    if [[ "$USE_DEFAULT_MAC" =~ ^[Nn]$ ]]; then
        read -rp "  Chemin complet du macaroon admin.macaroon : " MACAROON_PATH
    else
        MACAROON_PATH="$DEFAULT_MACAROON_PATH"
    fi
else
    warn "Macaroon Polar non trouvé à l'emplacement par défaut."
    echo -e "  Emplacement Polar standard : ${CYAN}~/.polar/networks/1/volumes/lnd/alice/data/chain/bitcoin/regtest/admin.macaroon${NC}"
    echo -e "  Vous pouvez aussi coller le hex directement depuis : Polar → Click sur le nœud → Onglet Connect → Macaroon (HEX)"
    echo ""
    read -rp "  (A) Chemin du fichier macaroon, ou (B) coller le hex ? [A/b] : " MAC_MODE
    if [[ "$MAC_MODE" =~ ^[Bb]$ ]]; then
        read -rp "  Collez le macaroon hex : " MACAROON_HEX_INPUT
        MACAROON_PATH=""
    else
        read -rp "  Chemin complet du macaroon : " MACAROON_PATH
    fi
fi

# Encoder en hex si un fichier a été fourni
if [ -n "$MACAROON_PATH" ]; then
    if [ ! -f "$MACAROON_PATH" ]; then
        error "Fichier macaroon introuvable : $MACAROON_PATH"
        exit 1
    fi
    MACAROON_HEX=$(xxd -p "$MACAROON_PATH" | tr -d '\n')
    success "Macaroon encodé en hex (${#MACAROON_HEX} caractères)"
elif [ -n "$MACAROON_HEX_INPUT" ]; then
    MACAROON_HEX="$MACAROON_HEX_INPUT"
    success "Macaroon hex accepté (${#MACAROON_HEX} caractères)"
else
    error "Aucun macaroon fourni."
    exit 1
fi

# Injecter dans polar_config.dart
if [ -f "$POLAR_CONFIG" ]; then
    # Utiliser Python pour gérer les caractères spéciaux dans sed
    python3 - "$POLAR_CONFIG" "$MACAROON_HEX" << 'PYEOF'
import sys, re

filepath = sys.argv[1]
new_hex  = sys.argv[2]

with open(filepath, 'r') as f:
    content = f.read()

content = re.sub(
    r"(static const String macaroonHex = ')[^']*(';)",
    rf"\g<1>{new_hex}\g<2>",
    content
)

with open(filepath, 'w') as f:
    f.write(content)

print("OK")
PYEOF
    success "polar_config.dart : macaroon injecté"
else
    warn "polar_config.dart introuvable — macaroon non injecté automatiquement."
    echo -e "  Ajoutez manuellement : ${CYAN}static const String macaroonHex = '$MACAROON_HEX';${NC}"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# ÉTAPE 6 — flutter pub get
# ══════════════════════════════════════════════════════════════════════════════
step "Étape 6/7 — Installation des dépendances Flutter"

cd "$SCRIPT_DIR"
info "Lancement de flutter pub get..."
if flutter pub get; then
    success "Dépendances installées"
else
    error "flutter pub get a échoué. Vérifiez pubspec.yaml."
    exit 1
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# ÉTAPE 7 — Vérification du pare-feu (Linux uniquement)
# ══════════════════════════════════════════════════════════════════════════════
step "Étape 7/7 — Vérification pare-feu (Linux)"

if command -v firewall-cmd &> /dev/null; then
    if firewall-cmd --list-ports 2>/dev/null | grep -q "${LND_PORT}/tcp"; then
        success "Pare-feu (firewalld) : port $LND_PORT déjà ouvert"
    else
        warn "Port $LND_PORT non ouvert dans firewalld."
        read -rp "  Ouvrir le port $LND_PORT maintenant ? (nécessite sudo) [O/n] : " OPEN_PORT
        if [[ ! "$OPEN_PORT" =~ ^[Nn]$ ]]; then
            if sudo firewall-cmd --add-port="${LND_PORT}/tcp" --permanent && sudo firewall-cmd --reload; then
                success "Port $LND_PORT ouvert dans firewalld"
            else
                warn "Impossible d'ouvrir le port automatiquement. Lancez manuellement :"
                echo -e "  ${CYAN}sudo firewall-cmd --add-port=${LND_PORT}/tcp --permanent && sudo firewall-cmd --reload${NC}"
            fi
        fi
    fi
elif command -v ufw &> /dev/null; then
    if ufw status 2>/dev/null | grep -q "$LND_PORT"; then
        success "Pare-feu (ufw) : port $LND_PORT déjà autorisé"
    else
        warn "Port $LND_PORT non autorisé dans ufw."
        read -rp "  Ouvrir le port $LND_PORT maintenant ? (nécessite sudo) [O/n] : " OPEN_UFW
        if [[ ! "$OPEN_UFW" =~ ^[Nn]$ ]]; then
            sudo ufw allow "$LND_PORT/tcp" && success "Port $LND_PORT autorisé dans ufw" || \
                warn "Erreur ufw. Lancez : sudo ufw allow $LND_PORT/tcp"
        fi
    fi
elif command -v iptables &> /dev/null; then
    warn "iptables détecté. Vérifiez manuellement que le port $LND_PORT est ouvert."
else
    info "Aucun pare-feu détecté — pas d'action requise."
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# RÉSUMÉ FINAL
# ══════════════════════════════════════════════════════════════════════════════
divider
echo -e "${BOLD}${GREEN}  ✅ Configuration terminée !${NC}"
divider
echo ""
echo -e "${BOLD}  Récapitulatif des modifications :${NC}"
echo -e "  • Nœud LND    : ${CYAN}https://$LOCAL_IP:$LND_PORT${NC}"
echo -e "  • Macaroon    : ${CYAN}${MACAROON_HEX:0:20}...${NC} (${#MACAROON_HEX} chars)"
echo -e "  • Android TLS : ${CYAN}$LOCAL_IP autorisé${NC}"
echo ""
echo -e "${BOLD}  Prochaines étapes :${NC}"
echo ""
echo -e "  1. Lancez ${BOLD}Polar${NC} et démarrez votre réseau Lightning"
echo -e "     (importez flash-network.polar si disponible)"
echo ""
echo -e "  2. Connectez votre appareil Android (USB debug activé)"
echo -e "     ou lancez un émulateur : ${CYAN}flutter emulators --launch <nom>${NC}"
echo ""
echo -e "  3. Lancez l'application :"
echo -e "     ${CYAN}flutter run${NC}"
echo ""
echo -e "  4. Vérifiez les logs LND dans le terminal :"
echo -e "     Filtrez avec : ${CYAN}flutter logs | grep '\\[LND\\]'${NC}"
echo ""
echo -e "  5. Si le nœud reste rouge dans l'appli :"
echo -e "     • Vérifiez que Polar est démarré"
echo -e "     • Testez : ${CYAN}curl -k -H 'Grpc-Metadata-Macaroon: $MACAROON_HEX' https://$LOCAL_IP:$LND_PORT/v1/getinfo${NC}"
echo ""
divider
echo -e "  Flash Wallet — Bitcoin Lightning pour l'Afrique de l'Ouest ⚡"
divider
echo ""
