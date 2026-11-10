#!/usr/bin/env bash
#
# wallselect.sh - Selector de fondos de pantalla para rofi + DMS
#
# Usa el shell DMS (Dux Shell) para aplicar el fondo, de modo que se
# reproduzcan sus transiciones animadas (disc, wipe, stripes, iris bloom,
# pixelate, portal, fade o random).
#
# Uso:
#   wallselect.sh                 Abre el menú de fondos
#   wallselect.sh --random        Aplica un fondo al azar
#   wallselect.sh --set RUTA      Aplica un fondo concreto
#   wallselect.sh --generate-thumbs
#   wallselect.sh --help
#
# Atajos dentro del menú:
#   Enter   aplicar el fondo seleccionado
#   Esc     cerrar
#

set -uo pipefail

# ---------------------------------------------------------------------------
# Configuración (se puede sobreescribir en config.sh)
# ---------------------------------------------------------------------------
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/wallselect/config.sh"
[[ -r "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

WALL_DIR="${WALL_DIR:-$HOME/Imágenes/Wallpapers}"
THEME="${THEME:-$HOME/.config/rofi/wallselect/style.rasi}"
CACHE_DIR="${CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/rofi-wallselect}"
THUMB_DIR="$CACHE_DIR/thumbs"
THUMB_W="${THUMB_W:-480}"
THUMB_H="${THUMB_H:-300}"
SHUFFLE="${SHUFFLE:-0}"
NOTIFY="${NOTIFY:-1}"
THEME_NOTIFY="${THEME_NOTIFY:-1}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

WALL_DIR="${WALL_DIR/#\~/$HOME}"
THEME="${THEME/#\~/$HOME}"
CACHE_DIR="${CACHE_DIR/#\~/$HOME}"

mkdir -p "$CACHE_DIR" "$THUMB_DIR"

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
die() {
    echo "wallselect: $*" >&2
    exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

if have magick; then
    MAGICK_BIN="magick"
elif have convert; then
    MAGICK_BIN="convert"
else
    MAGICK_BIN=""
fi

notify() {
    local title="$1" body="${2:-}" icon="${3:-}"
    [[ "$NOTIFY" -eq 1 ]] || return 0
    have notify-send || return 0
    local args=(-a "Fondos" "$title")
    [[ -n "$body" ]] && args+=("$body")
    [[ -n "$icon" && -f "$icon" ]] && args+=(-i "$icon")
    notify-send "${args[@]}" >/dev/null 2>&1 || true
}

# Ruta de la miniatura en caché para un fondo.
thumb_path() {
    local src="$1" key
    key=$(printf '%s' "$src" | md5sum | cut -d' ' -f1)
    printf '%s/%s.jpg\n' "$THUMB_DIR" "$key"
}

# Genera miniaturas en paralelo. Acepta rutas como argumentos.
generate_thumbs_parallel() {
    (($#)) || return 0
    [[ -n "$MAGICK_BIN" ]] || return 0

    printf '%s\0' "$@" | xargs -0 -r -P "$JOBS" -I{} bash -c '
        src=$1; cache=$2; bin=$3; tw=$4; th=$5
        key=$(printf "%s" "$src" | md5sum | cut -d" " -f1)
        dst="$cache/$key.jpg"
        if [[ -f $dst && $dst -nt $src ]]; then
            exit 0
        fi
        tmp="$dst.tmp.$$"
        if "$bin" "$src" \
            -auto-orient \
            -thumbnail "${tw}x${th}^" \
            -gravity center \
            -extent "${tw}x${th}" \
            -strip -quality 88 \
            "$tmp" >/dev/null 2>&1; then
            mv -f "$tmp" "$dst"
        else
            rm -f "$tmp"
        fi
    ' _ {} "$THUMB_DIR" "$MAGICK_BIN" "$THUMB_W" "$THUMB_H"
}

# Lista de fondos, delimitada por NUL.
load_files() {
    local -a found=()
    [[ -d "$WALL_DIR" ]] || die "no existe la carpeta $WALL_DIR"

    if [[ "$SHUFFLE" -eq 1 ]]; then
        mapfile -d '' -t found < <(
            find "$WALL_DIR" -type f \
                \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
                   -o -iname '*.webp' -o -iname '*.gif' \) -print0 |
            shuf -z
        )
    else
        mapfile -d '' -t found < <(
            find "$WALL_DIR" -type f \
                \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
                   -o -iname '*.webp' -o -iname '*.gif' \) -print0 |
            sort -z
        )
    fi

    printf '%s\0' "${found[@]}"
}

# Fondo actual según DMS.
get_current_wallpaper() {
    local out screen
    if have dms; then
        out=$(dms ipc call wallpaper get 2>/dev/null) || out=""
        case "$out" in
            ERROR:*[Pp]er-monitor*)
                screen=$(dms ipc call outputs current 2>/dev/null |
                    jq -r '.[0] // empty' 2>/dev/null)
                if [[ -z "$screen" ]]; then
                    screen=$(dms ipc call outputs current 2>/dev/null |
                        sed -n 's/.*"\([^"]*\)".*/\1/p' | head -n 1)
                fi
                [[ -n "$screen" ]] && out=$(dms ipc call wallpaper getFor "$screen" 2>/dev/null)
                ;;
            ERROR:*|"") out="" ;;
        esac
    fi
    printf '%s\n' "$out"
}

# Nombre legible de la transición configurada en DMS.
get_transition_label() {
    local raw="fade" session="$HOME/.local/state/dms/session.json"
    if [[ -f "$session" ]] && have jq; then
        raw=$(jq -r '.wallpaperTransition // "fade"' "$session" 2>/dev/null || echo fade)
    fi
    case "$raw" in
        random)      echo "Aleatoria" ;;
        none)        echo "Sin animación" ;;
        fade)        echo "Fundido" ;;
        wipe)        echo "Barrido" ;;
        disc)        echo "Disco" ;;
        stripes)     echo "Rayas" ;;
        "iris bloom") echo "Iris Bloom" ;;
        pixelate)    echo "Pixelado" ;;
        portal)      echo "Portal" ;;
        *)           echo "$raw" ;;
    esac
}

# ---------------------------------------------------------------------------
# Aplicar fondo (DMS primero; swww/swaybg como respaldo)
# ---------------------------------------------------------------------------
apply_wallpaper() {
    local img="$1" cur res screen
    [[ -f "$img" ]] || { notify "Fondo no encontrado" "$img"; return 1; }

    if have dms; then
        cur=$(dms ipc call wallpaper get 2>/dev/null) || cur=""
        case "$cur" in
            ERROR:*[Pp]er-monitor*)
                screen=$(dms ipc call outputs current 2>/dev/null |
                    jq -r '.[0] // empty' 2>/dev/null)
                if [[ -z "$screen" ]]; then
                    screen=$(dms ipc call outputs current 2>/dev/null |
                        sed -n 's/.*"\([^"]*\)".*/\1/p' | head -n 1)
                fi
                if [[ -n "$screen" ]]; then
                    res=$(dms ipc call wallpaper setFor "$screen" "$img" 2>&1)
                else
                    res="ERROR: no se pudo detectar el monitor"
                fi
                ;;
            *)
                res=$(dms ipc call wallpaper set "$img" 2>&1)
                ;;
        esac

        if [[ "$res" == SUCCESS:* ]]; then
            notify "Fondo cambiado" "$(basename "$img")" "$img"
            if [[ "$THEME_NOTIFY" -eq 1 ]]; then
                (
                    sleep 1.2
                    notify "Tema aplicado" "Colores generados desde $(basename "$img")"
                ) &
            fi
            return 0
        fi
        printf '%s\n' "$res" > "$CACHE_DIR/last-error.log"
    fi

    # Respaldo fuera de DMS -------------------------------------------------
    if have swww && swww query >/dev/null 2>&1; then
        swww img "$img" \
            --transition-type random \
            --transition-duration 1.2 \
            --transition-fps 60 \
            --transition-bezier .43,1.19,1,.4 >/dev/null 2>&1 &
    else
        pkill -x swaybg >/dev/null 2>&1 || true
        setsid swaybg -i "$img" -m fill >/dev/null 2>&1 &
    fi
    notify "Fondo cambiado" "$(basename "$img")" "$img"
}

# ---------------------------------------------------------------------------
# Geometría / fondo difuminado del menú
# ---------------------------------------------------------------------------
get_screen_width() {
    local res=""
    if have dms; then
        res=$(dms randr 2>/dev/null | awk '/Resolution:/ {print $2; exit}')
    fi
    if [[ -z "$res" ]] && have wlr-randr; then
        res=$(wlr-randr 2>/dev/null | awk '/current/ {print $1; exit}')
    fi
    if [[ -z "$res" ]] && have xrandr; then
        res=$(xrandr --current 2>/dev/null | awk '/\*/ {print $1; exit}')
    fi
    if [[ "$res" =~ ^([0-9]+)x[0-9]+$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo 1920
    fi
}

# Crea una versión difuminada y oscurecida del fondo actual.
make_background() {
    local current="$1" width="$2" height="$3" key bg
    [[ -n "$MAGICK_BIN" ]] || return 1
    [[ -n "$current" && -f "$current" ]] || return 1
    [[ "$current" == \#* ]] && return 1

    key=$(printf '%s' "$current" | md5sum | cut -d' ' -f1)
    bg="$CACHE_DIR/bg-${key}-${width}x${height}.jpg"
    if [[ ! -f "$bg" ]]; then
        "$MAGICK_BIN" "$current" \
            -auto-orient \
            -resize "${width}x${height}^" \
            -gravity center \
            -extent "${width}x${height}" \
            -blur 0x22 \
            -fill '#0a0a10' -colorize 52% \
            -strip -quality 82 \
            "$bg" >/dev/null 2>&1 || return 1
    fi
    printf '%s\n' "$bg"
}

# ---------------------------------------------------------------------------
# Menú principal
# ---------------------------------------------------------------------------
show_menu() {
    local -a files=() missing=()
    local img th icon current idx=0 i count mesg cols lines icon_size
    local screen_w win_w cell bg="" theme_str input_file rc selected
    local label

    mapfile -d '' -t files < <(load_files)
    ((${#files[@]})) || die "no se encontraron fondos en $WALL_DIR"

    # Genera las miniaturas que falten (en segundo plano si hay muchas).
    for img in "${files[@]}"; do
        th=$(thumb_path "$img")
        if [[ ! -f "$th" || "$img" -nt "$th" ]]; then
            missing+=("$img")
        fi
    done
    if ((${#missing[@]})) && [[ -n "$MAGICK_BIN" ]]; then
        generate_thumbs_parallel "${missing[@]}" >/dev/null 2>&1 &
    fi

    # Fondo actual y fila seleccionada inicialmente.
    current=$(get_current_wallpaper)
    for i in "${!files[@]}"; do
        if [[ "${files[$i]}" == "$current" ]]; then
            idx=$i
            break
        fi
    done

    # Geometría responsive.
    screen_w=$(get_screen_width)
    win_w=$((screen_w * 86 / 100))
    cols=6
    lines=3
    if ((screen_w < 1300)); then
        cols=4
    elif ((screen_w < 1600)); then
        cols=5
    fi
    cell=$(((win_w - 44 - (cols - 1) * 12) / cols))
    # En una celda vertical de rofi el icono ocupa todo el ancho disponible;
    # fijamos la caja a la altura que tendrá la miniatura (según THUMB_W/H)
    # para que las filas queden compactas y no sobre espacio vertical.
    icon_size=$(((cell - 20) * THUMB_H / THUMB_W + 2))
    ((icon_size > 400)) && icon_size=400
    ((icon_size < 90)) && icon_size=90

    # Fondo difuminado del menú.
    bg=$(make_background "$current" "$win_w" \
        "$((lines * (icon_size + 34) + 114))")

    # Entrada de rofi con iconos (formato dmenu con \0icon\x1f).
    input_file="$CACHE_DIR/menu-$$.input"
    : > "$input_file"
    for img in "${files[@]}"; do
        th=$(thumb_path "$img")
        if [[ -f "$th" && "$th" -nt "$img" ]]; then
            icon="$th"
        else
            icon="$img"
        fi
        printf '%s\0icon\x1f%s\n' "$img" "$icon" >> "$input_file"
    done

    count=${#files[@]}
    label=$(get_transition_label)
    mesg="<b>Fondos</b>  ·  <b>${count}</b> imágenes  ·  Transición: <b>${label}</b>"

    theme_str="listview { columns: ${cols}; lines: ${lines}; } element-icon { size: ${icon_size}px; }"
    if [[ -n "$bg" && -f "$bg" ]]; then
        theme_str="window { background-image: url(\"${bg}\", width); } ${theme_str}"
    fi

    selected=$(rofi -dmenu \
        -no-custom \
        -i \
        -show-icons \
        -p "Buscar" \
        -mesg "$mesg" \
        -input "$input_file" \
        -selected-row "$idx" \
        -kb-custom-1 "Ctrl+Shift+t" \
        -theme "$THEME" \
        -theme-str "$theme_str" \
        -window-title "Fondos" \
        2>"$CACHE_DIR/rofi.log")
    rc=$?

    rm -f "$input_file"

    case "$rc" in
        0)
            [[ -n "$selected" ]] && apply_wallpaper "$selected"
            ;;
        10)
            # Ctrl+Shift+T: ajustes de transición de DMS (pestaña Wallpaper).
            if have dms; then
                sleep 0.15
                dms ipc call settings openWith wallpaper >/dev/null 2>&1 ||
                    dms ipc call settings open >/dev/null 2>&1 || true
            fi
            ;;
        *)
            exit 0
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Argumentos
# ---------------------------------------------------------------------------
case "${1:-}" in
    --help|-h)
        cat <<'EOF'
wallselect.sh - selector de fondos para rofi + DMS

  --random              Aplica un fondo al azar con la animación de DMS
  --set RUTA            Aplica un fondo concreto
  --generate-thumbs     Genera/actualiza las miniaturas de la caché
  --dir RUTA            Usa otra carpeta de fondos
  --help                Muestra esta ayuda

Atajos del menú:
  Enter                 Aplicar fondo
  Esc                   Cerrar
EOF
        exit 0
        ;;
    --dir)
        [[ -n "${2:-}" ]] || die "--dir necesita una ruta"
        WALL_DIR="${2/#\~/$HOME}"
        ;;
    --set)
        [[ -n "${2:-}" ]] || die "--set necesita una ruta"
        apply_wallpaper "${2/#\~/$HOME}"
        exit $?
        ;;
    --random)
        mapfile -d '' -t all_files < <(load_files)
        ((${#all_files[@]})) || die "no se encontraron fondos en $WALL_DIR"
        pick=$(printf '%s\0' "${all_files[@]}" | shuf -z -n 1 | tr -d '\0')
        apply_wallpaper "$pick"
        exit $?
        ;;
    --generate-thumbs)
        mapfile -d '' -t all_files < <(load_files)
        ((${#all_files[@]})) || die "no se encontraron fondos en $WALL_DIR"
        echo "Generando miniaturas de ${#all_files[@]} fondos en $THUMB_DIR ..."
        generate_thumbs_parallel "${all_files[@]}"
        echo "Listo."
        exit 0
        ;;
esac

show_menu
