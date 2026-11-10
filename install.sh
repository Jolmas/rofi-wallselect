#!/usr/bin/env bash
#
# Instalador de rofi-wallselect.
#
# Copia el script y el tema a ~/.config/rofi/wallselect, crea la caché de
# miniaturas y respalda cualquier archivo que ya existiera.
#
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DEST="$CONFIG_HOME/rofi/wallselect"
SHARED="$CONFIG_HOME/rofi/shared"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-wallselect"
STAMP="$(date +%Y%m%d-%H%M%S)"
GEN_THUMBS=1

usage() {
    cat <<'EOF'
Uso: ./install.sh [opciones]

Opciones:
  --no-thumbs   No generar las miniaturas durante la instalación
  -h, --help    Mostrar esta ayuda
EOF
}

for arg in "$@"; do
    case "$arg" in
        --no-thumbs) GEN_THUMBS=0 ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "Opción desconocida: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

if ! command -v rofi >/dev/null 2>&1; then
    echo "Error: rofi no está instalado o no está en PATH." >&2
    echo "Instálalo antes de continuar (ver REQUIREMENTS.md)." >&2
    exit 1
fi

backup() {
    local file="$1"
    if [[ -e "$file" ]]; then
        cp -a "$file" "$file.bak.$STAMP"
        echo "  respaldo: $file.bak.$STAMP"
    fi
}

echo "Instalando rofi-wallselect en $DEST"
mkdir -p "$DEST" "$SHARED" "$CACHE/thumbs"

backup "$DEST/wallselect.sh"
backup "$DEST/style.rasi"
install -m 755 "$REPO_DIR/src/wallselect.sh" "$DEST/wallselect.sh"
install -m 644 "$REPO_DIR/src/style.rasi"     "$DEST/style.rasi"

if [[ -e "$DEST/config.sh" ]]; then
    echo "  conservando configuración existente: $DEST/config.sh"
else
    install -m 644 "$REPO_DIR/src/config.sh" "$DEST/config.sh"
fi

# Los archivos de ~/.config/rofi/shared son compartidos con otros temas de
# rofi. Solo se crean si no existen, para no pisar la paleta de matugen.
if [[ -e "$SHARED/colors.rasi" ]]; then
    echo "  conservando paleta existente: $SHARED/colors.rasi"
else
    install -m 644 "$REPO_DIR/src/shared/colors.rasi" "$SHARED/colors.rasi"
fi
if [[ -e "$SHARED/fonts.rasi" ]]; then
    echo "  conservando fuentes existentes: $SHARED/fonts.rasi"
else
    install -m 644 "$REPO_DIR/src/shared/fonts.rasi" "$SHARED/fonts.rasi"
fi

if (( GEN_THUMBS )); then
    if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
        echo "Generando miniaturas..."
        "$DEST/wallselect.sh" --generate-thumbs
    else
        echo "  ImageMagick no encontrado: se omite la generación de miniaturas."
        echo "  El menú funcionará igual usando las imágenes originales."
    fi
fi

echo
echo "Instalación completada."
echo "Abre el menú con:"
echo "  $DEST/wallselect.sh"
echo
