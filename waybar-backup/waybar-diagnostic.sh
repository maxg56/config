#!/bin/bash

# Script de diagnostic pour Waybar

echo "🔍 Diagnostic Waybar"
echo "==================="
echo ""

# Vérifier si Waybar est en cours d'exécution
if pgrep -x "waybar" > /dev/null; then
    echo "✅ Waybar est en cours d'exécution"
else
    echo "❌ Waybar n'est pas en cours d'exécution"
fi

# Vérifier les fichiers de configuration
WAYBAR_DIR="/home/maxence/.config/waybar"
echo ""
echo "📁 Fichiers de configuration :"

if [ -f "$WAYBAR_DIR/config.jsonc" ]; then
    echo "✅ config.jsonc existe"
else
    echo "❌ config.jsonc manquant"
fi

if [ -f "$WAYBAR_DIR/style.css" ]; then
    echo "✅ style.css existe"
else
    echo "❌ style.css manquant"
fi

if [ -f "$WAYBAR_DIR/theme.css" ]; then
    echo "✅ theme.css existe"
else
    echo "❌ theme.css manquant"
fi

# Vérifier les scripts
echo ""
echo "🛠️  Scripts utilitaires :"
for script in restart-waybar.sh style-switcher.sh; do
    if [ -f "$WAYBAR_DIR/$script" ]; then
        if [ -x "$WAYBAR_DIR/$script" ]; then
            echo "✅ $script (exécutable)"
        else
            echo "⚠️  $script (pas exécutable)"
        fi
    else
        echo "❌ $script manquant"
    fi
done

# Tester la syntaxe CSS (approximatif)
echo ""
echo "🎨 Vérification CSS :"
if command -v csslint >/dev/null 2>&1; then
    csslint "$WAYBAR_DIR/style.css" 2>/dev/null && echo "✅ CSS valide" || echo "⚠️  Problèmes CSS détectés"
else
    echo "ℹ️  csslint non installé, vérification basique..."
    # Vérification simple des accolades
    if [ $(grep -c '{' "$WAYBAR_DIR/style.css") -eq $(grep -c '}' "$WAYBAR_DIR/style.css") ]; then
        echo "✅ Accolades équilibrées"
    else
        echo "❌ Accolades déséquilibrées"
    fi
fi

# Conseils de dépannage
echo ""
echo "🔧 Conseils de dépannage :"
echo "   • Pour redémarrer : $WAYBAR_DIR/restart-waybar.sh"
echo "   • Pour changer de style : $WAYBAR_DIR/style-switcher.sh"
echo "   • Logs Waybar : journalctl --user -u waybar -f"
echo "   • Test manuel : waybar -c $WAYBAR_DIR/config.jsonc -s $WAYBAR_DIR/style.css"

echo ""
echo "🎯 Problèmes courants et solutions :"
echo "   • backdrop-filter non supporté → utilisez box-shadow"
echo "   • Propriétés CSS invalides → vérifiez la compatibilité GTK"
echo "   • Modules manquants → vérifiez config.jsonc"
