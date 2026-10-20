# Configuration Files

Personal configuration files for Hyprland desktop environment setup.

## Structure

### hypr/
Hyprland window manager configuration
- `hyprland.conf` - Main configuration file
- `animations.conf` - Animation settings
- `keybindings.conf` - Keyboard shortcuts
- `monitors.conf` - Monitor configuration
- `theme.conf` - Theme settings
- `windowrules.conf` - Window rules
- `hyprlock.conf` - Lock screen configuration
- `hyprpaper.conf` - Wallpaper configuration
- `Scripts/` - Utility scripts including song details
- `Fonts/` - Custom fonts (JetBrains Mono, SF Pro Display)

### waybar/
Status bar configuration and themes
- `config.jsonc` - Main waybar configuration
- `style.css` - Styling
- `scripts/` - Various system monitoring scripts
- `themes/` - Multiple color themes (Catppuccin, Gruvbox variants)

### rofi/
Application launcher configuration
- `config.rasi` - Main rofi configuration
- Theme files for menus (bluetooth, power, wifi)
- Multiple color themes in `themes/`

### kitty/
Terminal emulator configuration
- `kitty.conf` - Terminal settings
- `kitty-same-dir.sh` - Directory navigation script

### Thunar/
File manager configuration
- Custom actions and accelerators

## Themes

Supports multiple themes:
- Catppuccin (Frappe, Latte, Macchiato, Mocha)
- Gruvbox (Dark, Light)

Theme switching available through waybar scripts.

### claude/
Configuration de Claude Code (`settings.json`, `CLAUDE.md`, `plans/`).

## Sécurité

Les fichiers d'identifiants et l'état local des outils ne sont **pas** versionnés (voir `.gitignore`) :

- `claude/.credentials.json` est généré localement par `claude` lors de la connexion. Un modèle sans valeur réelle est fourni dans `claude/.credentials.json.example` ; ne jamais y mettre de vrai jeton.
- L'historique, les caches, la télémétrie et les todos de `claude/` sont ignorés.
- Les fichiers `.env`, `*.key`, `*.pem`, `credentials*` sont ignorés par défaut.

Si un identifiant a été publié par erreur, il doit être considéré comme compromis : le révoquer/régénérer côté service, même après l'avoir retiré du dépôt.
