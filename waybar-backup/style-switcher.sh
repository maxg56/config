#!/bin/bash

# Script pour appliquer différents niveaux d'amélioration visuelle

WAYBAR_CONFIG_DIR="/home/maxence/.config/waybar"

show_menu() {
    echo "🎨 Sélecteur de style Waybar amélioré"
    echo "=================================="
    echo "1. Style original (minimal)"
    echo "2. Style amélioré (actuel)"
    echo "3. Style glassmorphisme intense"
    echo "4. Style néon cyberpunk"
    echo "5. Redémarrer Waybar"
    echo "6. Quitter"
    echo ""
    read -p "Choisissez une option (1-6): " choice
}

apply_original() {
    echo "📦 Application du style original..."
    cp "$WAYBAR_CONFIG_DIR/style.css.backup" "$WAYBAR_CONFIG_DIR/style.css" 2>/dev/null || echo "⚠️  Pas de sauvegarde trouvée"
}

apply_enhanced() {
    echo "✨ Application du style amélioré..."
    # Le style actuel est déjà amélioré
    echo "Style amélioré déjà actif !"
}

apply_intense_glass() {
    echo "🌟 Application du style glassmorphisme intense..."
    
    # Ajouter des effets plus intenses
    cat > "$WAYBAR_CONFIG_DIR/intense-glass.css" << 'EOF'
/* Glassmorphisme intense */
window#waybar {
  background: rgba(17, 17, 27, 0.3) !important;
  backdrop-filter: blur(30px) saturate(1.8) !important;
  -webkit-backdrop-filter: blur(30px) saturate(1.8) !important;
}

window#waybar > box {
  background: linear-gradient(135deg, 
    rgba(49, 50, 68, 0.4) 0%, 
    rgba(88, 91, 112, 0.3) 50%, 
    rgba(69, 71, 90, 0.4) 100%) !important;
  border: 1px solid rgba(205, 214, 244, 0.5) !important;
  box-shadow: 
    0 12px 40px rgba(0, 0, 0, 0.6),
    inset 0 2px 0 rgba(255, 255, 255, 0.2) !important;
}

#workspaces button {
  background: rgba(147, 153, 178, 0.2) !important;
  backdrop-filter: blur(10px) !important;
}

#workspaces button:hover {
  background: rgba(137, 180, 250, 0.4) !important;
  box-shadow: 0 0 25px rgba(137, 180, 250, 0.6) !important;
}

#workspaces button.active {
  background: rgba(203, 166, 247, 0.5) !important;
  box-shadow: 0 0 30px rgba(203, 166, 247, 0.8) !important;
}
EOF
    
    echo '@import "intense-glass.css";' >> "$WAYBAR_CONFIG_DIR/style.css"
}

apply_cyberpunk() {
    echo "🌈 Application du style néon cyberpunk..."
    
    cat > "$WAYBAR_CONFIG_DIR/cyberpunk.css" << 'EOF'
/* Style Cyberpunk Néon */
window#waybar > box {
  background: linear-gradient(135deg, 
    rgba(17, 17, 27, 0.9) 0%, 
    rgba(49, 50, 68, 0.8) 50%, 
    rgba(17, 17, 27, 0.9) 100%) !important;
  border: 2px solid #ff00ff !important;
  box-shadow: 
    0 0 20px #ff00ff,
    inset 0 0 20px rgba(255, 0, 255, 0.1) !important;
  animation: neon-pulse 2s ease-in-out infinite !important;
}

@keyframes neon-pulse {
  0%, 100% { 
    border-color: #ff00ff; 
    box-shadow: 0 0 20px #ff00ff, inset 0 0 20px rgba(255, 0, 255, 0.1); 
  }
  50% { 
    border-color: #00ffff; 
    box-shadow: 0 0 30px #00ffff, inset 0 0 30px rgba(0, 255, 255, 0.2); 
  }
}

#workspaces button {
  color: #00ff00 !important;
  text-shadow: 0 0 10px #00ff00 !important;
}

#workspaces button:hover {
  color: #ff00ff !important;
  text-shadow: 0 0 15px #ff00ff !important;
  background: rgba(255, 0, 255, 0.2) !important;
}

#workspaces button.active {
  color: #00ffff !important;
  text-shadow: 0 0 20px #00ffff !important;
  background: rgba(0, 255, 255, 0.3) !important;
}

#clock, #cpu, #memory, #battery {
  color: #00ff00 !important;
  text-shadow: 0 0 8px currentColor !important;
}
EOF
    
    echo '@import "cyberpunk.css";' >> "$WAYBAR_CONFIG_DIR/style.css"
}

restart_waybar() {
    echo "🔄 Redémarrage de Waybar..."
    pkill waybar 2>/dev/null
    sleep 1
    waybar &
    echo "✅ Waybar redémarré !"
}

# Menu principal
while true; do
    show_menu
    
    case $choice in
        1)
            apply_original
            restart_waybar
            ;;
        2)
            apply_enhanced
            restart_waybar
            ;;
        3)
            apply_intense_glass
            restart_waybar
            ;;
        4)
            apply_cyberpunk
            restart_waybar
            ;;
        5)
            restart_waybar
            ;;
        6)
            echo "👋 Au revoir !"
            exit 0
            ;;
        *)
            echo "❌ Option invalide. Essayez encore."
            ;;
    esac
    
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
    clear
done
