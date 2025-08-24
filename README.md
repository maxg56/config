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