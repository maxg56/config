#!/bin/bash

# Script pour améliorer et redémarrer Waybar avec les nouveaux styles

echo "🎨 Application des améliorations visuelles de Waybar..."

# Tuer Waybar si il est en cours d'exécution
if pgrep -x "waybar" > /dev/null; then
    echo "⏹️  Arrêt de Waybar..."
    pkill waybar
    sleep 1
fi

# Redémarrer Waybar avec les nouveaux styles
echo "🚀 Redémarrage de Waybar avec les améliorations..."
waybar &

echo "✨ Waybar amélioré démarré avec succès !"
echo ""
echo "🎆 Améliorations visuelles appliquées :"
echo "   • Transitions fluides et animations CSS"
echo "   • Effets de hover avec élévation"
echo "   • Bordures arrondies modernes"
echo "   • Ombres portées réalistes"
echo "   • Couleurs thématiques pour chaque module"
echo "   • Workspaces avec bordures colorées"
echo "   • Animations de scale et rotation au survol"
echo ""
echo "💡 Conseil : Survolez les modules pour voir les nouveaux effets !"
echo "⚠️  Note : Version compatible sans backdrop-filter"
