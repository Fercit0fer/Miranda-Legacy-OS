#!/bin/bash
# ============================================================
#  MIRANDA LEGACY HOLDING OS — BUILD SCRIPT para GitHub Actions
#  Se ejecuta automáticamente en los servidores de GitHub
#  Powered by Claude · Anthropic
# ============================================================
set -e
export DEBIAN_FRONTEND=noninteractive

GRN="\033[32m"; BLU="\033[34m"; YEL="\033[33m"; RST="\033[0m"
log()  { echo -e "${BLU}[MLH BUILD]${RST} $1"; }
ok()   { echo -e "${GRN}[OK]${RST} $1"; }

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║  MIRANDA LEGACY HOLDING OS           ║"
echo "  ║  Build Automático via GitHub Actions ║"
echo "  ║  Powered by Claude · Anthropic       ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="/tmp/miranda-build"
OUTPUT_DIR="$REPO_DIR/output"

mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# ── CONFIGURAR LIVE-BUILD ─────────────────────────────────────
log "Configurando live-build Debian Bookworm 32-bit..."
cd "$BUILD_DIR"

lb config \
  --distribution bookworm \
  --architectures i386 \
  --binary-images iso-hybrid \
  --bootloaders grub-efi,syslinux \
  --debian-installer none \
  --mirror-bootstrap "http://deb.debian.org/debian" \
  --mirror-binary "http://deb.debian.org/debian" \
  --archive-areas "main contrib non-free non-free-firmware" \
  --apt-recommends false \
  --memtest none \
  --iso-volume "MirandaLegacyOS" \
  --iso-publisher "Miranda Legacy Holding · Powered by Claude" \
  --image-name "miranda-legacy-os-1.0" \
  --linux-flavours "686-pae" \
  --debootstrap-options "--no-merged-usr" \
  2>/dev/null || true

ok "live-build configurado"

# ── LISTA DE PAQUETES ─────────────────────────────────────────
log "Creando lista de paquetes..."
mkdir -p config/package-lists

cat > config/package-lists/miranda.list.chroot << 'PKGEOF'
xfce4
xfce4-terminal
xfce4-panel
xfce4-session
xfce4-settings
xfce4-power-manager
xfce4-screensaver
xfce4-taskmanager
thunar
thunar-archive-plugin
xfwm4
xfdesktop4
lightdm
lightdm-gtk-greeter
abiword
mousepad
gnome-calculator
firefox-esr
file-roller
ristretto
fonts-liberation
fonts-freefont-ttf
fonts-dejavu-core
pulseaudio
pavucontrol
alsa-utils
firmware-linux
firmware-linux-nonfree
firmware-realtek
firmware-brcm80211
linux-headers-686-pae
xserver-xorg-input-synaptics
xserver-xorg-video-intel
wine
wine32
network-manager
network-manager-gnome
ufw
ca-certificates
curl
wget
htop
rsync
unzip
zip
plymouth
gtk2-engines
gtk2-engines-murrine
calamares
calamares-settings-debian
PKGEOF
ok "Paquetes configurados"

# ── HOOKS DE CONFIGURACIÓN ────────────────────────────────────
log "Creando scripts de configuración interna..."
mkdir -p config/hooks/normal

# Copiar script de setup si existe
if [ -f "$REPO_DIR/scripts/miranda-setup.sh" ]; then
  cp "$REPO_DIR/scripts/miranda-setup.sh" config/hooks/normal/0099-miranda-setup.hook.chroot
  chmod +x config/hooks/normal/0099-miranda-setup.hook.chroot
fi

# Hook principal de configuración
cat > config/hooks/normal/0050-miranda-base.hook.chroot << 'HOOKEOF'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# ── LOGO MLH (SVG) ────────────────────────────────────────────
mkdir -p /usr/share/miranda/logo
cat > /usr/share/miranda/logo/mlh-icon.svg << 'SVGEOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg viewBox="0 0 32 38" xmlns="http://www.w3.org/2000/svg" width="32" height="38">
  <defs>
    <linearGradient id="sg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1a3a7a"/>
      <stop offset="100%" style="stop-color:#a6caf0"/>
    </linearGradient>
  </defs>
  <path d="M16 1 L31 8 L31 23 C31 32 24 37 16 38 C8 37 1 32 1 23 L1 8 Z"
        fill="url(#sg)" stroke="rgba(255,255,255,0.4)" stroke-width="1.5"/>
  <line x1="1" y1="16" x2="31" y2="16" stroke="rgba(255,255,255,0.2)" stroke-width="0.8"/>
  <text x="16" y="13" text-anchor="middle" font-family="Georgia,serif"
        font-size="11" fill="white" font-weight="bold">M</text>
  <text x="16" y="29" text-anchor="middle" font-family="Georgia,serif"
        font-size="7.5" fill="rgba(255,255,255,0.75)">LH</text>
</svg>
SVGEOF

# ── TEMA GTK WINDOWS 2000 ────────────────────────────────────
TDIR="/usr/share/themes/MirandaLegacy"
mkdir -p "$TDIR/gtk-2.0" "$TDIR/gtk-3.0" "$TDIR/xfwm4"

cat > "$TDIR/gtk-2.0/gtkrc" << 'GTKEOF'
gtk-color-scheme = "bg_color:#d4d0c8\nfg_color:#000000\nbase_color:#0e0e20\ntext_color:#c0c0d0\nselected_bg_color:#0a246a\nselected_fg_color:#ffffff\ntooltip_bg_color:#ffffe1\ntooltip_fg_color:#000000"
style "default" {
  bg[NORMAL]      = @bg_color
  bg[SELECTED]    = @selected_bg_color
  fg[NORMAL]      = @fg_color
  fg[SELECTED]    = @selected_fg_color
  base[NORMAL]    = @base_color
  text[NORMAL]    = @text_color
  text[SELECTED]  = @selected_fg_color
  font_name = "Tahoma 11"
}
class "*" style "default"
GTKEOF

cat > "$TDIR/gtk-3.0/gtk.css" << 'CSS3EOF'
* { font-family: Tahoma, Arial, sans-serif; font-size: 11px; }
window { background-color: #d4d0c8; color: #000; }
.titlebar, headerbar {
  background: linear-gradient(to right, #0a246a, #a6caf0);
  color: white; font-weight: bold; border: none; border-radius: 0;
  padding: 3px 6px; min-height: 22px;
}
button {
  background-color: #d4d0c8; color: #000; border-radius: 0;
  border: 1px solid; border-color: #fff #404040 #404040 #fff;
  box-shadow: inset -1px -1px 0 #808080, inset 1px 1px 0 #efefef;
  padding: 2px 10px; min-height: 23px;
}
button:active { border-color: #404040 #fff #fff #404040; }
entry, textview { background-color: #0e0e20; color: #c0c0d0; border-radius: 0; }
menubar { background-color: #d4d0c8; color: #000; }
menuitem:hover { background-color: #0a246a; color: #fff; }
selection { background-color: #0a246a; color: #fff; }
CSS3EOF

# XFWM4 (decoraciones)
cat > "$TDIR/xfwm4/themerc" << 'XEOF'
title_font=Tahoma Bold 11
button_offset=2
button_spacing=1
full_width_title=true
show_app_icon=true
shadow_opacity=0
XEOF

# ── WALLPAPER ─────────────────────────────────────────────────
mkdir -p /usr/share/miranda/wallpaper
python3 -c "
from PIL import Image, ImageDraw
w, h = 1024, 600
img = Image.new('RGB', (w, h))
d = ImageDraw.Draw(img)
for y in range(h):
    r = int(y/h * 2)
    g = int(y/h * 8)
    b = int(48 + y/h * 32)
    d.line([(0,y),(w,y)], fill=(r,g,b))
img.save('/usr/share/miranda/wallpaper/desktop.png')
img.save('/usr/share/miranda/wallpaper/login-bg.png')
" 2>/dev/null || convert -size 1024x600 gradient:"#001030"-"#002060" /usr/share/miranda/wallpaper/desktop.png 2>/dev/null || cp /usr/share/backgrounds/*.png /usr/share/miranda/wallpaper/desktop.png 2>/dev/null || true

# ── LIGHTDM ──────────────────────────────────────────────────
cat > /etc/lightdm/lightdm.conf << 'LDM'
[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=xfce
LDM

cat > /etc/lightdm/lightdm-gtk-greeter.conf << 'LGTK'
[greeter]
background=/usr/share/miranda/wallpaper/login-bg.png
theme-name=MirandaLegacy
font-name=Tahoma 11
clock-format=%H:%M
indicators=~host;~spacer;~clock;~spacer;~power
LGTK

# ── CONFIGURACIÓN XFCE BASE ──────────────────────────────────
SKEL="/etc/skel"
mkdir -p "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml"

# xsettings (tema, fuente, cursor)
cat > "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" << 'XS'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="MirandaLegacy"/>
    <property name="IconThemeName" type="string" value="hicolor"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Tahoma 11"/>
    <property name="MonospaceFontName" type="string" value="Courier New 10"/>
  </property>
</channel>
XS

# xfwm4 (ventanas)
cat > "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" << 'XW'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="MirandaLegacy"/>
    <property name="title_font" type="string" value="Tahoma Bold 11"/>
    <property name="button_layout" type="string" value="O|HMC"/>
    <property name="use_compositing" type="bool" value="false"/>
    <property name="workspace_count" type="int" value="1"/>
  </property>
</channel>
XW

# Wallpaper
cat > "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" << 'XD'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/miranda/wallpaper/desktop.png"/>
          <property name="image-style" type="int" value="4"/>
        </property>
      </property>
    </property>
  </property>
</channel>
XD

# Panel (taskbar)
cat > "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" << 'XP'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=8;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="26"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="6"/>
        <value type="int" value="7"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="applicationsmenu">
      <property name="show-button-title" type="bool" value="true"/>
      <property name="button-title" type="string" value="Inicio"/>
      <property name="button-icon" type="string" value="/usr/share/miranda/logo/mlh-icon.svg"/>
    </property>
    <property name="plugin-2" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-3" type="string" value="tasklist">
      <property name="show-labels" type="bool" value="true"/>
    </property>
    <property name="plugin-4" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-5" type="string" value="power-manager-plugin"/>
    <property name="plugin-6" type="string" value="systray"/>
    <property name="plugin-7" type="string" value="clock">
      <property name="digital-format" type="string" value="%H:%M"/>
    </property>
  </property>
</channel>
XP

# Atajos de teclado Windows-like
cat > "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml" << 'XK'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-keyboard-shortcuts" version="1.0">
  <property name="commands" type="empty">
    <property name="custom" type="empty">
      <property name="Super_L+l" type="string" value="xfce4-screensaver-command --lock"/>
      <property name="Super_L+d" type="string" value="xfdesktop --arrange"/>
      <property name="Super_L+e" type="string" value="thunar"/>
      <property name="Super_L+r" type="string" value="xfce4-appfinder --collapsed"/>
      <property name="ctrl+alt+Delete" type="string" value="xfce4-taskmanager"/>
      <property name="ctrl+alt+t" type="string" value="xfce4-terminal"/>
    </property>
  </property>
  <property name="xfwm4" type="empty">
    <property name="custom" type="empty">
      <property name="alt+F4" type="string" value="close_window_key"/>
      <property name="alt+Tab" type="string" value="cycle_windows_key"/>
    </property>
  </property>
</channel>
XK

# ── FIREFOX POLÍTICAS ────────────────────────────────────────
mkdir -p /usr/lib/firefox-esr/distribution
cat > /usr/lib/firefox-esr/distribution/policies.json << 'FF'
{
  "policies": {
    "DisableTelemetry": true,
    "DisablePocket": true,
    "DisableFirefoxStudies": true,
    "Homepage": {"URL": "about:blank", "Locked": false},
    "Preferences": {
      "browser.newtabpage.enabled": false,
      "privacy.donottrackheader.enabled": true
    }
  }
}
FF

# ── WINE 32-BIT ──────────────────────────────────────────────
mkdir -p /etc/skel/.wine
cat > /etc/skel/.wine/user.reg << 'WR'
REGEDIT4
[HKEY_CURRENT_USER\Software\Wine]
"Version"="winxp"
WR

# ── README EN ESCRITORIO ─────────────────────────────────────
mkdir -p /etc/skel/Desktop
cat > /etc/skel/Desktop/Miranda-Legacy-README.txt << 'RD'
======================================
  MIRANDA LEGACY HOLDING OS v1.0
  Powered by Claude · Anthropic
======================================

ATAJOS DE TECLADO:
  Win + L     → Bloquear pantalla
  Win + D     → Mostrar escritorio
  Win + E     → Explorador de archivos
  Win + R     → Ejecutar programa
  Ctrl+Alt+Del → Gestor de tareas
  Alt+F4      → Cerrar ventana
  Alt+Tab     → Cambiar ventana

PROGRAMAS:
  Firefox ESR    → Navegador web
  Abiword        → Documentos
  Mousepad       → Editor de texto (Notepad)
  Calculadora    → Calculadora científica
  Thunar         → Explorador de archivos
  Wine           → Ejecutar programas .exe

PARA TUS JUEGOS WINDOWS:
  Doble clic en el archivo .exe
  (o clic derecho → Abrir con Wine)

© Miranda Legacy Holding · Powered by Claude
RD

# ── UFW (FIREWALL) ───────────────────────────────────────────
ufw default deny incoming 2>/dev/null || true
ufw default allow outgoing 2>/dev/null || true

echo "[Miranda Legacy] Configuración interna completada ✓"
HOOKEOF
chmod +x config/hooks/normal/0050-miranda-base.hook.chroot
ok "Hooks de configuración creados"

# ── CONFIGURACIÓN GRUB ────────────────────────────────────────
log "Configurando pantalla de inicio (GRUB)..."
mkdir -p config/bootloaders/grub-pc 2>/dev/null || true

# ── CONSTRUIR ────────────────────────────────────────────────
log "Iniciando construcción del ISO..."
log "Esto tomará entre 30 y 60 minutos..."
echo ""

sudo lb build 2>&1

# ── RESULTADO ────────────────────────────────────────────────
if ls *.iso 1>/dev/null 2>&1; then
  mv *.iso "$OUTPUT_DIR/Miranda-Legacy-Holding-OS-1.0-i386.iso"
  SIZE=$(du -sh "$OUTPUT_DIR/Miranda-Legacy-Holding-OS-1.0-i386.iso" | cut -f1)
  echo ""
  echo "  ╔══════════════════════════════════════╗"
  echo "  ║  ✅ ISO GENERADA EXITOSAMENTE        ║"
  echo "  ║  Miranda-Legacy-Holding-OS-1.0-i386  ║"
  echo "  ║  Tamaño: $SIZE                        ║"
  echo "  ╚══════════════════════════════════════╝"
  echo ""
else
  echo "⚠️ No se encontró el ISO. Revisando directorio..."
  ls -la
  exit 1
fi
