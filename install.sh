#!/bin/bash

# Script d'installation pour la configuration Hyprland
# Installation script for Hyprland configuration

set -e

echo "🚀 Installation de la configuration Hyprland..."

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier si on est sur Arch Linux
if ! command -v pacman &> /dev/null; then
    print_error "Ce script est conçu pour Arch Linux avec pacman"
    exit 1
fi

# Installation des paquets nécessaires
print_status "Installation des paquets requis..."

packages=(
    "hyprland"
    "waybar"
    "rofi"
    "kitty"
    "thunar"
    "hyprlock"
    "hyprpaper"
    "dunst"
    "pipewire"
    "pipewire-pulse"
    "wireplumber"
    "brightnessctl"
    "playerctl"
    "grim"
    "slurp"
    "wl-clipboard"
    "xdg-desktop-portal-hyprland"
)

for package in "${packages[@]}"; do
    if ! pacman -Q "$package" &> /dev/null; then
        print_status "Installation de $package..."
        sudo pacman -S --noconfirm "$package"
    else
        print_success "$package est déjà installé"
    fi
done

# Créer les répertoires de configuration
print_status "Création des répertoires de configuration..."

config_dirs=(
    "$HOME/.config/hypr"
    "$HOME/.config/waybar"
    "$HOME/.config/rofi"
    "$HOME/.config/kitty"
    "$HOME/.config/Thunar"
    "$HOME/.config/dconf"
)

for dir in "${config_dirs[@]}"; do
    mkdir -p "$dir"
    print_success "Répertoire créé: $dir"
done

# Copier les fichiers de configuration
print_status "Copie des fichiers de configuration..."

# Sauvegarder les configurations existantes
backup_dir="$HOME/.config/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"

if [ -d "$HOME/.config/hypr" ]; then
    print_warning "Sauvegarde de la configuration Hyprland existante..."
    cp -r "$HOME/.config/hypr" "$backup_dir/"
fi

# Copier les nouvelles configurations
cp -r ./hypr/* "$HOME/.config/hypr/"
cp -r ./waybar/* "$HOME/.config/waybar/"
cp -r ./rofi/* "$HOME/.config/rofi/"
cp -r ./kitty/* "$HOME/.config/kitty/"
cp -r ./Thunar/* "$HOME/.config/Thunar/"

# Rendre les scripts exécutables
print_status "Définition des permissions pour les scripts..."
find "$HOME/.config/hypr/Scripts" -name "*.sh" -exec chmod +x {} \;
find "$HOME/.config/waybar/scripts" -name "*.sh" -exec chmod +x {} \;
chmod +x "$HOME/.config/kitty/kitty-same-dir.sh"

# Installer les polices
print_status "Installation des polices..."
fonts_dir="$HOME/.local/share/fonts"
mkdir -p "$fonts_dir"

if [ -d "./hypr/Fonts" ]; then
    cp -r ./hypr/Fonts/* "$fonts_dir/"
    fc-cache -fv
    print_success "Polices installées"
fi

# Configuration de dconf si nécessaire
if [ -f "./dconf/user" ]; then
    print_status "Restauration des paramètres dconf..."
    cp ./dconf/user "$HOME/.config/dconf/"
fi

# Vérifier et installer les dépendances Python pour waybar
print_status "Vérification des dépendances Python..."
if command -v pip &> /dev/null; then
    pip install --user requests
fi

print_success "Installation terminée!"
echo ""
echo "📋 Étapes suivantes:"
echo "1. Redémarrez votre session ou relancez Hyprland"
echo "2. Vérifiez que tous les scripts fonctionnent correctement"
echo "3. Personnalisez les configurations selon vos préférences"
echo ""
print_warning "Sauvegarde des anciennes configurations dans: $backup_dir"
echo ""
print_success "Profitez de votre nouvelle configuration Hyprland! 🎉"