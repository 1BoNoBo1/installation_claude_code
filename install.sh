#!/bin/bash

# =============================================================================
# Script d'installation Claude Code avec configuration MCP complète
# Pour Ubuntu/Debian
# =============================================================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Installation Claude Code + MCP Servers               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# -----------------------------------------------------------------------------
# 1. Vérification des prérequis
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[1/7] Vérification des prérequis...${NC}"

# Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js non trouvé. Installation...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo -e "${GREEN}✓ Node.js $(node --version)${NC}"
fi

# npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}npm non trouvé.${NC}"
    exit 1
else
    echo -e "${GREEN}✓ npm $(npm --version)${NC}"
fi

# npx
if ! command -v npx &> /dev/null; then
    echo -e "${RED}npx non trouvé.${NC}"
    exit 1
else
    echo -e "${GREEN}✓ npx disponible${NC}"
fi

# Python3 + pip
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Python3 non trouvé. Installation...${NC}"
    sudo apt-get install -y python3 python3-pip
else
    echo -e "${GREEN}✓ Python $(python3 --version)${NC}"
fi

# uv/uvx (pour certains MCP servers)
if ! command -v uvx &> /dev/null; then
    echo -e "${YELLOW}uvx non trouvé. Installation...${NC}"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
else
    echo -e "${GREEN}✓ uvx disponible${NC}"
fi

# GitHub CLI
if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}GitHub CLI non trouvé. Installation...${NC}"
    sudo apt-get install -y gh || {
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install gh -y
    }
else
    echo -e "${GREEN}✓ GitHub CLI $(gh --version | head -1)${NC}"
fi

echo

# -----------------------------------------------------------------------------
# 2. Installation de Claude Code
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[2/7] Installation de Claude Code...${NC}"

if command -v claude &> /dev/null; then
    echo -e "${GREEN}✓ Claude Code déjà installé ($(claude --version 2>/dev/null || echo 'version inconnue'))${NC}"
else
    echo "Téléchargement et installation de Claude Code..."
    # Installation native (recommandée)
    curl -fsSL https://claude.ai/install.sh | sh
fi

echo

# -----------------------------------------------------------------------------
# 3. Configuration des répertoires
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[3/7] Création des répertoires...${NC}"

mkdir -p "$HOME/databases"
mkdir -p "$HOME/.claude/commands"

echo -e "${GREEN}✓ Répertoires créés${NC}"
echo

# -----------------------------------------------------------------------------
# 4. Configuration PostgreSQL (optionnel)
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[4/7] Configuration PostgreSQL...${NC}"

if command -v psql &> /dev/null; then
    echo "PostgreSQL détecté. Création de la base 'claude'..."
    sudo -u postgres createdb claude 2>/dev/null || echo "Base 'claude' existe déjà ou erreur"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE claude TO $USER;" 2>/dev/null || true
    echo -e "${GREEN}✓ PostgreSQL configuré${NC}"
else
    echo -e "${YELLOW}⚠ PostgreSQL non installé. Serveur MCP postgres désactivé.${NC}"
    echo "  Pour l'installer: sudo apt-get install postgresql"
fi

echo

# -----------------------------------------------------------------------------
# 5. Configuration des serveurs MCP
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[5/7] Configuration des serveurs MCP...${NC}"

# Récupérer le token GitHub si gh est authentifié
GITHUB_TOKEN=""
if gh auth status &>/dev/null; then
    GITHUB_TOKEN=$(gh auth token 2>/dev/null || echo "")
    echo -e "${GREEN}✓ Token GitHub récupéré depuis gh CLI${NC}"
else
    echo -e "${YELLOW}⚠ GitHub CLI non authentifié. Exécutez 'gh auth login' plus tard.${NC}"
fi

# Ajouter les serveurs MCP
echo "Ajout des serveurs MCP..."

claude mcp add filesystem -s user -- npx -y @modelcontextprotocol/server-filesystem "$HOME" 2>/dev/null || true
claude mcp add memory -s user -- npx -y @modelcontextprotocol/server-memory 2>/dev/null || true
claude mcp add sequential-thinking -s user -- npx -y @modelcontextprotocol/server-sequential-thinking 2>/dev/null || true
claude mcp add fetch -s user -- uvx mcp-server-fetch 2>/dev/null || true
claude mcp add puppeteer -s user -- npx -y @modelcontextprotocol/server-puppeteer 2>/dev/null || true
claude mcp add sqlite -s user -- uvx mcp-server-sqlite --db-path "$HOME/databases/claude.db" 2>/dev/null || true

if command -v psql &> /dev/null; then
    claude mcp add postgres -s user -- npx -y @modelcontextprotocol/server-postgres "postgresql://$USER@localhost/claude" 2>/dev/null || true
fi

if [ -n "$GITHUB_TOKEN" ]; then
    # Ajouter github avec le token dans l'env
    claude mcp add github -s user -- npx -y @modelcontextprotocol/server-github 2>/dev/null || true
    # Le token sera ajouté manuellement dans ~/.claude.json
fi

echo -e "${GREEN}✓ Serveurs MCP configurés${NC}"
echo

# -----------------------------------------------------------------------------
# 6. Configuration CLAUDE.md
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[6/7] Configuration CLAUDE.md...${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/config/CLAUDE.md.template" ]; then
    # Demander les infos utilisateur
    read -p "Votre nom d'utilisateur: " USERNAME
    read -p "Votre email: " EMAIL

    # Créer CLAUDE.md personnalisé
    sed -e "s/__USERNAME__/$USERNAME/g" \
        -e "s/__EMAIL__/$EMAIL/g" \
        -e "s|\$HOME|$HOME|g" \
        -e "s|\$USER|$USER|g" \
        "$SCRIPT_DIR/config/CLAUDE.md.template" > "$HOME/CLAUDE.md"

    echo -e "${GREEN}✓ CLAUDE.md créé dans $HOME${NC}"
else
    echo -e "${YELLOW}⚠ Template CLAUDE.md non trouvé. Création manuelle requise.${NC}"
fi

echo

# -----------------------------------------------------------------------------
# 7. Configuration Chromium isolé (optionnel)
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[7/7] Configuration Chromium isolé pour Claude...${NC}"

CHROMIUM_CLAUDE_DIR="$HOME/snap/chromium/common/chromium-claude"

if command -v chromium-browser &> /dev/null || command -v chromium &> /dev/null; then
    mkdir -p "$CHROMIUM_CLAUDE_DIR"

    # Créer le lanceur desktop
    DESKTOP_FILE="$HOME/.local/share/applications/chromium-claude.desktop"
    mkdir -p "$(dirname "$DESKTOP_FILE")"

    cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.0
Name=Chromium Claude
Comment=Chromium isolé pour Claude for Chrome
Exec=chromium-browser --user-data-dir=$CHROMIUM_CLAUDE_DIR %U
Icon=chromium-browser
Terminal=false
Type=Application
Categories=Network;WebBrowser;
EOF

    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    echo -e "${GREEN}✓ Chromium Claude configuré${NC}"
else
    echo -e "${YELLOW}⚠ Chromium non installé. Installation optionnelle: sudo snap install chromium${NC}"
fi

echo

# -----------------------------------------------------------------------------
# Résumé
# -----------------------------------------------------------------------------
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Installation terminée!                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${GREEN}Prochaines étapes:${NC}"
echo "  1. Lancez 'claude' et connectez-vous"
echo "  2. Si pas fait: 'gh auth login' pour GitHub"
echo "  3. Vérifiez les MCP: 'claude mcp list'"
echo
echo -e "${YELLOW}Serveurs MCP installés:${NC}"
echo "  • filesystem  - Accès fichiers $HOME"
echo "  • memory      - Graphe de connaissances"
echo "  • sequential-thinking - Raisonnement structuré"
echo "  • fetch       - Récupération web"
echo "  • puppeteer   - Automatisation navigateur"
echo "  • sqlite      - Base locale"
echo "  • postgres    - Base PostgreSQL (si installé)"
echo "  • github      - Intégration GitHub (si authentifié)"
echo
