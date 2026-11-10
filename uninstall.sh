#!/usr/bin/env bash
#
# Desinstalador de rofi-wallselect.
#
# Por defecto elimina el script y el tema, pero conserva config.sh y los
# archivos compartidos de ~/.config/rofi/shared (los usan otros temas).
#
set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DEST="$CONFIG_HOME/rofi/wallselect"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-wallselect"
PURGE=0

usage() {
    cat <<'EOF'
Uso: ./uninstall.sh [opciones]

Opciones:
  --purge       Elimina también config.sh y la caché de miniaturas
  -h, --help    Mostrar esta ayuda
EOF
}

for arg in "$@"; do
    case "$arg" in
        --purge)   PURGE=1 ;;
        -h|--help) usage; exit 0 ;;
        *)         echo "Opción desconocida: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

echo "Desinstalando rofi-wallselect de $DEST"
rm -f "$DEST/wallselect.sh" "$DEST/style.rasi"

if (( PURGE )); then
    rm -f "$DEST/config.sh"
    rm -rf "$CACHE"
    echo "  eliminados config.sh y la caché $CACHE"
else
    echo "  conservando $DEST/config.sh"
    echo "  conservando la caché $CACHE (usa --purge para borrarla)"
fi

rmdir "$DEST" 2>/dev/null || true

echo
echo "Hecho. Los archivos de $CONFIG_HOME/rofi/shared no se tocan porque"
echo "pueden ser utilizados por otros temas de rofi."
