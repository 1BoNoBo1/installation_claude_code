# Installation Claude Code

Script d'installation pour reproduire une configuration Claude Code complète avec serveurs MCP sur Ubuntu/Debian.

## Contenu

```
installation_claude_code/
├── install.sh                    # Script d'installation automatique
├── config/
│   ├── mcp-servers.json          # Référence des serveurs MCP (documentation)
│   └── CLAUDE.md.template        # Template pour CLAUDE.md
└── README.md
```

> **Note** : Le fichier `config/mcp-servers.json` est une **référence documentaire** uniquement. Les variables `$HOME` et `$USER` ne sont pas interprétées dans un fichier JSON. L'installation réelle utilise le script `install.sh` qui appelle `claude mcp add` avec les bonnes substitutions.

## Serveurs MCP inclus

| Serveur | Description |
|---------|-------------|
| **filesystem** | Accès aux fichiers du répertoire home |
| **memory** | Graphe de connaissances persistant |
| **sequential-thinking** | Raisonnement structuré multi-étapes |
| **fetch** | Récupération de contenu web |
| **puppeteer** | Automatisation navigateur (scraping, screenshots) |
| **sqlite** | Base de données SQLite locale |
| **postgres** | Base de données PostgreSQL |
| **github** | Intégration GitHub (issues, PRs, repos) |

## Installation rapide

```bash
git clone https://github.com/1BoNoBo1/installation_claude_code.git
cd installation_claude_code
./install.sh
```

## Installation manuelle

### 1. Prérequis

```bash
# Node.js 24.x
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs

# Python + uv
sudo apt-get install -y python3 python3-pip
curl -LsSf https://astral.sh/uv/install.sh | sh

# GitHub CLI
sudo apt-get install -y gh

# PostgreSQL (optionnel)
sudo apt-get install -y postgresql
```

### 2. Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | sh
```

### 3. Serveurs MCP

```bash
# Créer les répertoires
mkdir -p ~/databases ~/.claude/commands

# Ajouter les serveurs
claude mcp add filesystem -s user -- npx -y @modelcontextprotocol/server-filesystem "$HOME"
claude mcp add memory -s user -- npx -y @modelcontextprotocol/server-memory
claude mcp add sequential-thinking -s user -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add fetch -s user -- uvx mcp-server-fetch
claude mcp add puppeteer -s user -- npx -y @modelcontextprotocol/server-puppeteer
claude mcp add sqlite -s user -- uvx mcp-server-sqlite --db-path ~/databases/claude.db
claude mcp add postgres -s user -- npx -y @modelcontextprotocol/server-postgres "postgresql://$USER@localhost/claude"
claude mcp add github -s user -- npx -y @modelcontextprotocol/server-github
```

### 4. GitHub Token

```bash
# Authentification GitHub CLI
gh auth login

# Le token sera automatiquement disponible pour le MCP github
```

### 5. PostgreSQL

```bash
sudo -u postgres createdb claude
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE claude TO $USER;"
```

### 6. CLAUDE.md

Copier `config/CLAUDE.md.template` vers `~/CLAUDE.md` et personnaliser.

## Chromium isolé (optionnel)

Pour utiliser Claude for Chrome dans un environnement isolé :

```bash
# Créer le profil isolé
mkdir -p ~/snap/chromium/common/chromium-claude

# Lancer avec profil isolé
chromium-browser --user-data-dir=~/snap/chromium/common/chromium-claude
```

## Vérification

```bash
# Vérifier les serveurs MCP
claude mcp list

# Doit afficher 8 serveurs connectés
```

## Sauvegarde/Restauration

### Sauvegarder

```bash
tar -czvf claude-backup.tar.gz \
    ~/.claude.json \
    ~/.claude/ \
    ~/CLAUDE.md \
    ~/databases/claude.db
```

### Restaurer

```bash
tar -xzvf claude-backup.tar.gz -C ~/
```

## Dépendances

- Node.js 24.x
- Python 3.x
- uv/uvx
- GitHub CLI (gh)
- PostgreSQL (optionnel)
- Chromium (optionnel)

## Licence

MIT

## Auteur

1BoNoBo1
