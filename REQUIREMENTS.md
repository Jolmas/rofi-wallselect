# Requerimientos

## Obligatorios

| Dependencia | Versión / notas | Uso |
|-------------|-----------------|-----|
| `bash` | 4.3 o superior | Ejecutar el script |
| `rofi` | 1.7 o superior (probado con 2.0.0-next) | Menú, iconos, `-theme-str` |
| `coreutils` | `install`, `md5sum`, `sort`, `nproc`, `setsid` | Instalación y script |
| `findutils` | `find` | Listar fondos |

## Recomendados

| Dependencia | Uso | Si falta… |
|-------------|-----|-----------|
| `DMS` (DankMaterialShell) | Aplicar el fondo con transiciones animadas | Se intenta `swww` y luego `swaybg` |
| `ImageMagick` (`magick` o `convert`) | Miniaturas y fondo difuminado | Usa las imágenes originales y color sólido |
| `jq` | Modo multi-monitor y etiqueta de transición | Algunas funciones degradan |
| `libnotify` (`notify-send`) | Notificaciones | Sin notificaciones |
| `wlr-randr` o `xrandr` | Detectar resolución si DMS no responde | Asume 1920 px de ancho |
| Fuente `Inter` | Tipografía del tema | rofi usa su fuente por defecto |

## Opcionales

- `swww`: transiciones alternativas si no usas DMS.
- `swaybg`: último respaldo para mostrar el fondo.
- `matugen` / `pywal`: paleta dinámica en
  `~/.config/rofi/colors/wallpaper.rasi`.

> **Nota sobre swww:** en algunas sesiones Wayland (por ejemplo, ciertas
> versiones de labwc/wlroots) `swww` puede fallar al decodificar imágenes con
> `InvalidEnumDiscriminant(("Format", ...))`. En ese caso usa DMS, que es el
> backend recomendado por este proyecto.

## Instalación por distribución

### Arch Linux

```bash
sudo pacman -S rofi imagemagick jq libnotify wlr-randr
```

### Debian / Ubuntu

```bash
sudo apt install rofi imagemagick jq libnotify-bin wlr-randr
```

### Fedora

```bash
sudo dnf install rofi ImageMagick jq libnotify wlr-randr
```

### openSUSE

```bash
sudo zypper install rofi ImageMagick jq libnotify-tools wlr-randr
```

## DMS (DankMaterialShell)

DMS no suele estar en los repositorios de las distribuciones. Instálalo desde
su proyecto oficial y asegúrate de que el servicio de usuario está activo:

```bash
systemctl --user status dms
```

Comandos que utiliza este menú:

```bash
dms ipc call wallpaper get
dms ipc call wallpaper set RUTA
dms ipc call wallpaper setFor MONITOR RUTA
dms ipc call settings openWith wallpaper
dms ipc call outputs current
```
