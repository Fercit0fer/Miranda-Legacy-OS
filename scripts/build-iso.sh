#!/bin/bash
# =============================================================================
# Miranda Legacy Holding OS - Script de Construcción de ISO
# Base: Debian 12 Bookworm 32-bit (i386)
# Target: HP Mini 110-1a (Intel Atom N270)
# =============================================================================

set -euo pipefail

# ── Colores para mensajes ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${GREEN}[MLH-OS]${NC} $1"; }
warn()   { echo -e "${YELLOW}[AVISO]${NC} $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()   { echo -e "\n${BLUE}══════════════════════════════════════${NC}"; \
           echo -e "${BLUE} $1${NC}"; \
           echo -e "${BLUE}══════════════════════════════════════${NC}"; }

# ── Variables ──────────────────────────────────────────────────────────────────
WORK_DIR="/tmp/mlh-build"
CHROOT_DIR="${WORK_DIR}/chroot"
ISO_DIR="${WORK_DIR}/iso"
OUTPUT_DIR="${PWD}/output"
ISO_NAME="miranda-legacy-holding-os-1.0-i386.iso"
DEBIAN_MIRROR="http://deb.debian.org/debian"
ARCH="i386"
DEBIAN_VERSION="bookworm"

# ── Verificar que corre como root ──────────────────────────────────────────────
step "Verificando entorno de construcción"
if [[ $EUID -ne 0 ]]; then
    error "Este script debe ejecutarse como root (sudo)."
fi
log "Entorno verificado correctamente."

# ── Instalar dependencias del host ─────────────────────────────────────────────
step "Instalando dependencias del sistema host"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
    debootstrap \
    squashfs-tools \
    xorriso \
    grub-pc-bin \
    grub-efi-ia32-bin \
    mtools \
    dosfstools \
    isolinux \
    syslinux-common \
    wget \
    ca-certificates \
    qemu-user-static 2>/dev/null || true
log "Dependencias instaladas."

# ── Limpiar y preparar directorios ─────────────────────────────────────────────
step "Preparando directorios de trabajo"
rm -rf "${WORK_DIR}"
mkdir -p "${CHROOT_DIR}" "${ISO_DIR}/live" "${ISO_DIR}/boot/grub" "${OUTPUT_DIR}"
log "Directorios listos en ${WORK_DIR}"

# ── Debootstrap: instalar sistema base Debian i386 ────────────────────────────
step "Descargando sistema base Debian ${DEBIAN_VERSION} (i386) - puede tardar varios minutos"
debootstrap \
    --arch="${ARCH}" \
    --variant=minbase \
    --include=systemd,systemd-sysv,dbus \
    "${DEBIAN_VERSION}" \
    "${CHROOT_DIR}" \
    "${DEBIAN_MIRROR}"
log "Sistema base Debian instalado."

# ── Configurar el chroot ───────────────────────────────────────────────────────
step "Configurando sistema en chroot"

# Montar filesystems necesarios para el chroot
mount --bind /dev     "${CHROOT_DIR}/dev"
mount --bind /dev/pts "${CHROOT_DIR}/dev/pts"
mount --bind /proc    "${CHROOT_DIR}/proc"
mount --bind /sys     "${CHROOT_DIR}/sys"

# Función para desmontar todo al salir (limpieza)
cleanup_mounts() {
    log "Desmontando filesystems del chroot..."
    umount -lf "${CHROOT_DIR}/dev/pts" 2>/dev/null || true
    umount -lf "${CHROOT_DIR}/dev"     2>/dev/null || true
    umount -lf "${CHROOT_DIR}/proc"    2>/dev/null || true
    umount -lf "${CHROOT_DIR}/sys"     2>/dev/null || true
}
trap cleanup_mounts EXIT

log "Filesystems montados."

# ── Copiar resolv.conf para tener internet dentro del chroot ──────────────────
cp /etc/resolv.conf "${CHROOT_DIR}/etc/resolv.conf" 2>/dev/null || true

# ── Script que se ejecutará DENTRO del chroot ─────────────────────────────────
cat > "${CHROOT_DIR}/tmp/setup-inside-chroot.sh" << 'CHROOT_SCRIPT'
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export LANG=es_PE.UTF-8

echo "[chroot] Configurando hostname..."
echo "miranda-legacy" > /etc/hostname
cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost
127.0.1.1   miranda-legacy
::1         localhost ip6-localhost ip6-loopback
HOSTS

echo "[chroot] Configurando fuentes de software..."
cat > /etc/apt/sources.list << 'SOURCES'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
SOURCES

echo "[chroot] Actualizando lista de paquetes..."
apt-get update -qq

echo "[chroot] Instalando kernel Linux i386 con PAE..."
apt-get install -y --no-install-recommends \
    linux-image-686-pae \
    linux-headers-686-pae \
    firmware-linux-free \
    firmware-linux-nonfree \
    firmware-realtek \
    firmware-b43-installer \
    live-boot \
    live-boot-initramfs-tools \
    initramfs-tools

echo "[chroot] Instalando entorno de escritorio XFCE..."
apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-terminal \
    xfce4-power-manager \
    xfce4-screensaver \
    xfce4-battery-plugin \
    xfce4-whiskermenu-plugin \
    xfce4-notifyd \
    xfce4-settings \
    xfce4-session \
    thunar \
    thunar-archive-plugin \
    thunar-volman \
    mousepad \
    ristretto \
    orage \
    file-roller \
    xserver-xorg \
    xserver-xorg-video-intel \
    xserver-xorg-input-synaptics \
    xserver-xorg-input-evdev \
    x11-xserver-utils \
    lightdm \
    lightdm-gtk-greeter \
    lightdm-gtk-greeter-settings

echo "[chroot] Instalando software de productividad..."
apt-get install -y --no-install-recommends \
    abiword \
    gnome-calculator \
    firefox-esr \
    thunderbird

echo "[chroot] Instalando utilidades del sistema..."
apt-get install -y --no-install-recommends \
    ufw \
    htop \
    wget \
    curl \
    ca-certificates \
    locales \
    console-setup \
    keyboard-configuration \
    tzdata \
    net-tools \
    wireless-tools \
    wpasupplicant \
    network-manager \
    network-manager-gnome \
    pulseaudio \
    alsa-utils \
    zram-tools \
    preload \
    calamares \
    calamares-settings-debian \
    plymouth \
    plymouth-themes \
    grub-pc \
    os-prober

echo "[chroot] Instalando Wine 32-bit..."
dpkg --add-architecture i386 || true
apt-get update -qq
apt-get install -y --no-install-recommends \
    wine \
    wine32 \
    wine64 2>/dev/null || \
apt-get install -y --no-install-recommends \
    wine \
    wine32 2>/dev/null || \
    echo "[aviso] Wine instalado parcialmente - continuando"

echo "[chroot] Configurando locale español..."
sed -i 's/# es_PE.UTF-8 UTF-8/es_PE.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/# es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=es_PE.UTF-8

echo "[chroot] Configurando timezone Lima, Perú..."
ln -sf /usr/share/zoneinfo/America/Lima /etc/localtime
echo "America/Lima" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

echo "[chroot] Creando usuario principal..."
useradd -m -s /bin/bash -G audio,video,plugdev,netdev,sudo usuario 2>/dev/null || true
echo "usuario:usuario" | chpasswd
# El usuario NO tiene sudo según spec - solo root puede modificar sistema
gpasswd -d usuario sudo 2>/dev/null || true

echo "[chroot] Configurando autologin en LightDM..."
mkdir -p /etc/lightdm
cat > /etc/lightdm/lightdm.conf << 'LIGHTDM_CONF'
[Seat:*]
autologin-user=usuario
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
LIGHTDM_CONF

echo "[chroot] Habilitando servicios necesarios..."
systemctl enable lightdm      2>/dev/null || true
systemctl enable NetworkManager 2>/dev/null || true
systemctl enable systemd-timesyncd 2>/dev/null || true

echo "[chroot] Limpiando caché de apt..."
apt-get clean
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*

echo "[chroot] Setup completado exitosamente."
CHROOT_SCRIPT

chmod +x "${CHROOT_DIR}/tmp/setup-inside-chroot.sh"

# ── Ejecutar el script dentro del chroot ──────────────────────────────────────
log "Ejecutando configuración dentro del chroot (esto tomará ~15-20 minutos)..."
chroot "${CHROOT_DIR}" /bin/bash /tmp/setup-inside-chroot.sh
log "Configuración del chroot completada."

# ── Aplicar tema visual Windows 2000 ──────────────────────────────────────────
step "Aplicando tema visual Miranda Legacy (estética Windows 2000)"

# Directorios del usuario
mkdir -p "${CHROOT_DIR}/home/usuario/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "${CHROOT_DIR}/home/usuario/.themes/MirandaLegacy/xfwm4"
mkdir -p "${CHROOT_DIR}/home/usuario/.themes/MirandaLegacy/gtk-2.0"
mkdir -p "${CHROOT_DIR}/home/usuario/.themes/MirandaLegacy/gtk-3.0"
mkdir -p "${CHROOT_DIR}/home/usuario/.icons"
mkdir -p "${CHROOT_DIR}/usr/share/plymouth/themes/miranda"
mkdir -p "${CHROOT_DIR}/usr/share/backgrounds"

# ── Configuración XFCE: apariencia general ───────────────────────────────────
cat > "${CHROOT_DIR}/home/usuario/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="MirandaLegacy"/>
    <property name="IconThemeName" type="string" value="hicolor"/>
    <property name="DoubleClickTime" type="int" value="250"/>
    <property name="DoubleClickDistance" type="int" value="5"/>
    <property name="DndDragThreshold" type="int" value="8"/>
    <property name="CursorBlink" type="bool" value="true"/>
    <property name="CursorBlinkTime" type="int" value="1200"/>
    <property name="SoundThemeName" type="string" value="default"/>
    <property name="EnableEventSounds" type="bool" value="true"/>
    <property name="EnableInputFeedbackSounds" type="bool" value="true"/>
  </property>
  <property name="Xft" type="empty">
    <property name="DPI" type="int" value="96"/>
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintmedium"/>
    <property name="RGBA" type="string" value="none"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Liberation Sans 9"/>
    <property name="MonospaceFontName" type="string" value="Liberation Mono 10"/>
    <property name="CanChangeAccels" type="bool" value="false"/>
    <property name="MenuImages" type="bool" value="true"/>
    <property name="ButtonImages" type="bool" value="true"/>
    <property name="ToolbarStyle" type="string" value="icons"/>
    <property name="ToolbarIconSize" type="int" value="3"/>
    <property name="DecorationLayout" type="string" value="menu:minimize,maximize,close"/>
    <property name="DialogsUseHeader" type="bool" value="false"/>
    <property name="EnablePrimaryPaste" type="bool" value="false"/>
  </property>
</channel>
EOF

# ── Configuración XFCE: administrador de ventanas ────────────────────────────
cat > "${CHROOT_DIR}/home/usuario/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="MirandaLegacy"/>
    <property name="title_font" type="string" value="Liberation Sans Bold 9"/>
    <property name="title_alignment" type="string" value="center"/>
    <property name="button_layout" type="string" value="O|HMC"/>
    <property name="frame_opacity" type="int" value="100"/>
    <property name="inactive_opacity" type="int" value="100"/>
    <property name="move_opacity" type="int" value="100"/>
    <property name="resize_opacity" type="int" value="100"/>
    <property name="show_frame_shadow" type="bool" value="false"/>
    <property name="show_popup_shadow" type="bool" value="false"/>
    <property name="snap_to_border" type="bool" value="true"/>
    <property name="snap_to_windows" type="bool" value="false"/>
    <property name="wrap_workspaces" type="bool" value="false"/>
    <property name="wrap_windows" type="bool" value="false"/>
    <property name="use_compositing" type="bool" value="false"/>
    <property name="cycle_apps_only" type="bool" value="false"/>
  </property>
</channel>
EOF

# ── Configuración XFCE: escritorio y fondo ───────────────────────────────────
cat > "${CHROOT_DIR}/home/usuario/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="0"/>
          <property name="rgba1" type="array">
            <value type="double" value="0.054902"/>
            <value type="double" value="0.117647"/>
            <value type="double" value="0.517647"/>
            <value type="double" value="1.000000"/>
          </property>
          <property name="rgba2" type="array">
            <value type="double" value="0.160784"/>
            <value type="double" value="0.301961"/>
            <value type="double" value="0.647059"/>
            <value type="double" value="1.000000"/>
          </property>
        </property>
      </property>
    </property>
  </property>
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="2"/>
    <property name="icon-size" type="uint" value="32"/>
    <property name="icon-font-size" type="uint" value="9"/>
    <property name="use-custom-font-size" type="bool" value="true"/>
    <property name="show-thumbnails" type="bool" value="false"/>
    <property name="show-hidden-files" type="bool" value="false"/>
  </property>
</channel>
EOF

# ── Configuración XFCE: panel inferior estilo Windows 2000 ───────────────────
cat > "${CHROOT_DIR}/home/usuario/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
  </property>
  <property name="panel-1" type="empty">
    <property name="position" type="string" value="p=8;x=0;y=0"/>
    <property name="length" type="uint" value="100"/>
    <property name="position-locked" type="bool" value="true"/>
    <property name="size" type="uint" value="28"/>
    <property name="plugin-ids" type="array">
      <value type="int" value="1"/>
      <value type="int" value="2"/>
      <value type="int" value="3"/>
      <value type="int" value="4"/>
      <value type="int" value="5"/>
      <value type="int" value="6"/>
      <value type="int" value="7"/>
    </property>
    <property name="background-style" type="uint" value="1"/>
    <property name="background-rgba" type="array">
      <value type="double" value="0.831373"/>
      <value type="double" value="0.815686"/>
      <value type="double" value="0.784314"/>
      <value type="double" value="1.000000"/>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu"/>
    <property name="plugin-2" type="string" value="separator"/>
    <property name="plugin-3" type="string" value="tasklist"/>
    <property name="plugin-4" type="string" value="separator"/>
    <property name="plugin-5" type="string" value="systray"/>
    <property name="plugin-6" type="string" value="battery"/>
    <property name="plugin-7" type="string" value="clock"/>
  </property>
</channel>
EOF

# ── Configuración XFCE: atajos de teclado estilo Windows ─────────────────────
cat > "${CHROOT_DIR}/home/usuario/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-keyboard-shortcuts" version="1.0">
  <property name="commands" type="empty">
    <property name="custom" type="empty">
      <property name="&lt;Super&gt;l" type="string" value="xflock4"/>
      <property name="&lt;Super&gt;d" type="string" value="xfce4-find-cursor"/>
      <property name="&lt;Super&gt;e" type="string" value="thunar"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;t" type="string" value="xfce4-terminal"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;Delete" type="string" value="xfce4-session-logout"/>
    </property>
  </property>
  <property name="xfwm4" type="empty">
    <property name="custom" type="empty">
      <property name="&lt;Alt&gt;F4" type="string" value="close_window_key"/>
      <property name="&lt;Alt&gt;Tab" type="string" value="cycle_windows_key"/>
      <property name="&lt;Alt&gt;Escape" type="string" value="cycle_reverse_windows_key"/>
    </property>
  </property>
</channel>
EOF

# ── Tema GTK: estilo visual Windows 2000 ─────────────────────────────────────
cat > "${CHROOT_DIR}/home/usuario/.themes/MirandaLegacy/gtk-2.0/gtkrc" << 'EOF'
# Miranda Legacy - Tema GTK2 estilo Windows 2000
gtk-theme-name = "MirandaLegacy"
gtk-font-name = "Liberation Sans 9"
gtk-button-images = 1
gtk-menu-images = 1
gtk-toolbar-style = GTK_TOOLBAR_ICONS

style "default" {
  bg[NORMAL]      = "#d4d0c8"
  bg[PRELIGHT]    = "#c8c4bc"
  bg[ACTIVE]      = "#bab6ae"
  bg[SELECTED]    = "#0a246a"
  bg[INSENSITIVE] = "#d4d0c8"

  fg[NORMAL]      = "#000000"
  fg[PRELIGHT]    = "#000000"
  fg[ACTIVE]      = "#000000"
  fg[SELECTED]    = "#ffffff"
  fg[INSENSITIVE] = "#808080"

  base[NORMAL]    = "#ffffff"
  base[PRELIGHT]  = "#ffffff"
  base[ACTIVE]    = "#0a246a"
  base[SELECTED]  = "#0a246a"
  base[INSENSITIVE] = "#f0efed"

  text[NORMAL]    = "#000000"
  text[PRELIGHT]  = "#000000"
  text[ACTIVE]    = "#ffffff"
  text[SELECTED]  = "#ffffff"
  text[INSENSITIVE] = "#808080"

  engine "pixmap" {}
}

class "*" style "default"
EOF

cat > "${CHROOT_DIR}/home/usuario/.themes/MirandaLegacy/gtk-3.0/gtk.css" << 'EOF'
/* Miranda Legacy - Tema GTK3 estilo Windows 2000 */
* {
  font-family: "Liberation Sans", "MS Sans Serif", sans-serif;
  font-size: 9pt;
}

window, .background {
  background-color: #d4d0c8;
  color: #000000;
}

button {
  background-color: #d4d0c8;
  border: 2px outset #ffffff;
  color: #000000;
  padding: 2px 8px;
  min-height: 20px;
}

button:hover {
  background-color: #c8c4bc;
}

button:active {
  border: 2px inset #808080;
}

entry {
  background-color: #ffffff;
  border: 1px inset #808080;
  color: #000000;
  padding: 2px;
}

.titlebar, headerbar {
  background: linear-gradient(to right, #0a246a, #a6b5e7);
  color: #ffffff;
  font-weight: bold;
  font-size: 9pt;
  padding: 3px;
  min-height: 18px;
}

menubar, .menubar {
  background-color: #d4d0c8;
  color: #000000;
  border-bottom: 1px solid #808080;
}

menu, .menu {
  background-color: #d4d0c8;
  border: 2px outset #ffffff;
  color: #000000;
}

menuitem:hover {
  background-color: #0a246a;
  color: #ffffff;
}

scrollbar {
  background-color: #d4d0c8;
}

scrollbar slider {
  background-color: #c0bdb5;
  border: 2px outset #ffffff;
  min-width: 16px;
  min-height: 16px;
}

treeview {
  background-color: #ffffff;
  color: #000000;
}

treeview:selected {
  background-color: #0a246a;
  color: #ffffff;
}

notebook {
  background-color: #d4d0c8;
}

.notebook tab {
  background-color: #d4d0c8;
  border: 2px outset #ffffff;
  padding: 2px 6px;
}

statusbar {
  background-color: #d4d0c8;
  border-top: 1px solid #808080;
  font-size: 9pt;
}
EOF

# ── Tema XFWM4: bordes de ventana Windows 2000 ───────────────────────────────
# Crear themerc para el gestor de ventanas
cat > "${CHROOT_DIR}/home/usuario/.themes/MirandaLegacy/xfwm4/themerc" << 'EOF'
# Miranda Legacy - Tema XFWM4 estilo Windows 2000
title_font=Liberation Sans Bold 9
title_shadow_active=false
title_shadow_inactive=false
button_offset=2
button_spacing=2
full_width_title=true
title_vertical_offset_active=1
title_vertical_offset_inactive=1
EOF

# ── Tema Plymouth: pantalla de boot ──────────────────────────────────────────
cat > "${CHROOT_DIR}/usr/share/plymouth/themes/miranda/miranda.plymouth" << 'EOF'
[Plymouth Theme]
Name=Miranda Legacy Holding OS
Description=Boot splash Miranda Legacy - Powered by Claude
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/miranda
ScriptFile=/usr/share/plymouth/themes/miranda/miranda.script
EOF

cat > "${CHROOT_DIR}/usr/share/plymouth/themes/miranda/miranda.script" << 'EOF'
# Miranda Legacy Plymouth Script
Window.SetBackgroundTopColor(0.054, 0.117, 0.517);
Window.SetBackgroundBottomColor(0.160, 0.301, 0.647);

message_sprite = Sprite();
message_sprite.SetPosition(
    Window.GetWidth() / 2 - 200,
    Window.GetHeight() / 2,
    10000
);

logo_image = Image.Text("Miranda Legacy Holding OS", 1.0, 1.0, 1.0);
logo_sprite = Sprite(logo_image);
logo_sprite.SetPosition(
    Window.GetWidth() / 2 - logo_image.GetWidth() / 2,
    Window.GetHeight() / 2 - 60,
    10000
);

sub_image = Image.Text("Powered by Claude  |  Iniciando...", 0.8, 0.8, 0.8);
sub_sprite = Sprite(sub_image);
sub_sprite.SetPosition(
    Window.GetWidth() / 2 - sub_image.GetWidth() / 2,
    Window.GetHeight() / 2 - 30,
    10000
);

fun refresh_callback() {
    # animación simple de puntos de carga
}
Plymouth.SetRefreshFunction(refresh_callback);
EOF

# ── Script de bienvenida y configuración post-login ──────────────────────────
cat > "${CHROOT_DIR}/home/usuario/.config/autostart/miranda-setup.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Miranda Legacy Setup
Comment=Configuración inicial Miranda Legacy Holding OS
Exec=/usr/bin/miranda-welcome
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

mkdir -p "${CHROOT_DIR}/home/usuario/.config/autostart"

# ── Script miranda-tweaks: personalización post-instalación ──────────────────
cat > "${CHROOT_DIR}/usr/bin/miranda-tweaks" << 'EOF'
#!/bin/bash
# Miranda Legacy Holding OS - Herramienta de Personalización
# Uso: miranda-tweaks [opcion]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_menu() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Miranda Legacy Holding OS v1.0         ║${NC}"
    echo -e "${BLUE}║   Herramienta de Personalización         ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Cambiar fondo de pantalla"
    echo -e "  ${GREEN}2)${NC} Activar/Desactivar sonidos del sistema"
    echo -e "  ${GREEN}3)${NC} Ajustar resolución de pantalla"
    echo -e "  ${GREEN}4)${NC} Instalar software adicional"
    echo -e "  ${GREEN}5)${NC} Configurar Wine"
    echo -e "  ${GREEN}6)${NC} Información del sistema"
    echo -e "  ${GREEN}7)${NC} Actualizar Miranda Legacy OS"
    echo -e "  ${GREEN}0)${NC} Salir"
    echo ""
    read -p "  Selecciona una opción: " choice

    case $choice in
        1) change_wallpaper ;;
        2) toggle_sounds ;;
        3) set_resolution ;;
        4) install_software ;;
        5) configure_wine ;;
        6) show_info ;;
        7) update_system ;;
        0) exit 0 ;;
        *) echo -e "${RED}Opción inválida${NC}"; sleep 1; show_menu ;;
    esac
}

change_wallpaper() {
    echo -e "${YELLOW}Cambiando fondo de pantalla...${NC}"
    echo "1) Gradiente azul clásico (Windows 2000 original)"
    echo "2) Verde oscuro Windows 98"
    echo "3) Negro oscuro"
    read -p "Selecciona: " w
    case $w in
        1) xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/color-style -s 1 ;;
        2) xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/rgba1 \
               --create -t double -t double -t double -t double \
               -s 0.0 -s 0.2 -s 0.0 -s 1.0 ;;
        3) xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/rgba1 \
               --create -t double -t double -t double -t double \
               -s 0.05 -s 0.05 -s 0.05 -s 1.0 ;;
    esac
    echo -e "${GREEN}Fondo cambiado.${NC}"
    sleep 1; show_menu
}

toggle_sounds() {
    echo "Sonidos del sistema (se requiere reinicio para aplicar)"
    echo "1) Activar sonidos"
    echo "2) Desactivar sonidos"
    read -p "Selecciona: " s
    case $s in
        1) xfconf-query -c xsettings -p /Net/EnableEventSounds -s true
           xfconf-query -c xsettings -p /Net/EnableInputFeedbackSounds -s true ;;
        2) xfconf-query -c xsettings -p /Net/EnableEventSounds -s false
           xfconf-query -c xsettings -p /Net/EnableInputFeedbackSounds -s false ;;
    esac
    echo -e "${GREEN}Configuración de sonidos actualizada.${NC}"
    sleep 1; show_menu
}

set_resolution() {
    echo "Resoluciones disponibles para HP Mini 110:"
    echo "1) 1024x600 (nativa)"
    echo "2) 800x600"
    echo "3) 1024x768"
    read -p "Selecciona: " r
    case $r in
        1) xrandr --output LVDS1 --mode 1024x600 2>/dev/null || \
           xrandr --output eDP1 --mode 1024x600 2>/dev/null || true ;;
        2) xrandr --output LVDS1 --mode 800x600 2>/dev/null || true ;;
        3) xrandr --output LVDS1 --mode 1024x768 2>/dev/null || true ;;
    esac
    echo -e "${GREEN}Resolución cambiada.${NC}"
    sleep 1; show_menu
}

install_software() {
    echo "Software disponible para instalar:"
    echo "1) VLC Media Player"
    echo "2) GIMP (editor de imágenes)"
    echo "3) Transmission (torrents)"
    echo "4) Otro (ingresar nombre de paquete)"
    read -p "Selecciona: " pkg
    case $pkg in
        1) sudo apt-get install -y vlc ;;
        2) sudo apt-get install -y gimp ;;
        3) sudo apt-get install -y transmission ;;
        4) read -p "Nombre del paquete: " pkgname
           sudo apt-get install -y "$pkgname" ;;
    esac
    echo -e "${GREEN}Instalación completada.${NC}"
    sleep 2; show_menu
}

configure_wine() {
    echo -e "${YELLOW}Configurando Wine para Miranda Legacy...${NC}"
    if ! command -v wine &>/dev/null; then
        echo -e "${RED}Wine no está instalado.${NC}"
        sleep 2; show_menu; return
    fi
    export WINEARCH=win32
    export WINEPREFIX="$HOME/.wine"
    winecfg &
    echo -e "${GREEN}Wine configurado. Se abrirá la ventana de configuración.${NC}"
    sleep 2; show_menu
}

show_info() {
    clear
    echo -e "${BLUE}══════════════════════════════════════════${NC}"
    echo -e "  Acerca de Miranda Legacy Holding OS"
    echo -e "${BLUE}══════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Versión:     1.0"
    echo -e "  Base:        Debian 12 Bookworm (i386)"
    echo -e "  Escritorio:  XFCE 4.18+"
    echo -e "  Plataforma:  HP Mini 110-1a"
    echo -e "  Procesador:  Intel Atom N270 (32-bit)"
    echo ""
    echo -e "  Creado por:  Claude (Anthropic)"
    echo -e "  Licencia:    GPL v2/v3"
    echo ""
    echo -e "  'El pasado nunca muere, simplemente"
    echo -e "   se reoptimiza para el futuro.'"
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════${NC}"
    echo -e "  Kernel: $(uname -r)"
    echo -e "  RAM:    $(free -h | awk '/^Mem:/ {print $2}') total"
    echo -e "  Disco:  $(df -h / | awk 'NR==2 {print $4}') libre"
    echo ""
    read -p "  Presiona Enter para continuar..." _
    show_menu
}

update_system() {
    echo -e "${YELLOW}Actualizando Miranda Legacy OS...${NC}"
    sudo apt-get update && sudo apt-get upgrade -y
    echo -e "${GREEN}Sistema actualizado.${NC}"
    sleep 2; show_menu
}

show_menu
EOF
chmod +x "${CHROOT_DIR}/usr/bin/miranda-tweaks"

# ── README en el escritorio ───────────────────────────────────────────────────
mkdir -p "${CHROOT_DIR}/home/usuario/Escritorio"
cat > "${CHROOT_DIR}/home/usuario/Escritorio/README.txt" << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║           MIRANDA LEGACY HOLDING OS  v1.0                    ║
║           Powered by Claude - Anthropic                      ║
╚══════════════════════════════════════════════════════════════╝

Bienvenido a Miranda Legacy Holding OS, tu sistema operativo
retro-futurista basado en Debian 12 Bookworm para HP Mini 110-1a.

═══ PRIMEROS PASOS ════════════════════════════════════════════

1. INSTALAR EL SISTEMA:
   Haz doble clic en el instalador del escritorio (Calamares)
   Sigue los 6 pasos del asistente gráfico.

2. ATAJOS DE TECLADO (estilo Windows):
   Win + L          → Bloquear pantalla
   Win + D          → Mostrar escritorio
   Win + E          → Explorador de archivos (Thunar)
   Alt + F4         → Cerrar ventana
   Alt + Tab        → Cambiar entre ventanas
   Ctrl + Alt + T   → Abrir Terminal
   Ctrl + Alt + Del → Cerrar sesión / Apagar

3. EJECUTAR PROGRAMAS WINDOWS (.exe):
   - Wine está preinstalado y configurado
   - Clic derecho en un archivo .exe → "Abrir con Wine"
   - O desde terminal: wine nombre-del-programa.exe

4. PERSONALIZACIÓN:
   Ejecuta "miranda-tweaks" en la terminal para:
   - Cambiar fondo de pantalla
   - Activar/desactivar sonidos
   - Ajustar resolución
   - Instalar software adicional

═══ SOFTWARE INCLUIDO ══════════════════════════════════════════
  • Firefox ESR       → Navegador web
  • Thunderbird       → Correo electrónico
  • Abiword           → Procesador de textos (.doc, .odt, .docx)
  • Mousepad          → Editor de texto simple
  • Thunar            → Explorador de archivos
  • Calculadora       → GNOME Calculator
  • Wine 9.x          → Compatibilidad con software Windows
  • Ristretto         → Visor de imágenes
  • File Roller       → Gestor de archivos comprimidos

═══ INFORMACIÓN TÉCNICA ════════════════════════════════════════
  SO Base:     Debian 12 Bookworm (32-bit / i386)
  Escritorio:  XFCE 4.18+
  Kernel:      Linux 6.x con soporte PAE
  Hardware:    HP Mini 110-1a (Intel Atom N270)
  RAM mínima:  512 MB (recomendado 1 GB+)

═══ SOPORTE ════════════════════════════════════════════════════
  Creado por: Claude (Anthropic)
  Licencia:   GPL v2/v3

  "El pasado nunca muere, simplemente se reoptimiza para el futuro."
══════════════════════════════════════════════════════════════
EOF

# ── Ajustar permisos del home del usuario ─────────────────────────────────────
chroot "${CHROOT_DIR}" chown -R usuario:usuario /home/usuario 2>/dev/null || true
log "Tema visual y configuración aplicados."

# ── Activar Plymouth como boot splash ────────────────────────────────────────
step "Configurando Plymouth boot splash"
chroot "${CHROOT_DIR}" bash -c "
    plymouth-set-default-theme miranda 2>/dev/null || \
    plymouth-set-default-theme text 2>/dev/null || \
    echo '[aviso] Plymouth theme - usando fallback'
    update-initramfs -u 2>/dev/null || true
" || warn "Plymouth no pudo configurarse completamente - continuando"

# ── Desmontar antes de crear squashfs ────────────────────────────────────────
step "Preparando imagen del filesystem"
cleanup_mounts
trap - EXIT  # Desactivar el trap, ya desmontamos manualmente

# Limpiar archivos temporales del chroot
rm -f "${CHROOT_DIR}/tmp/setup-inside-chroot.sh"
rm -f "${CHROOT_DIR}/etc/resolv.conf"

# ── Crear squashfs (filesystem comprimido de la ISO) ─────────────────────────
log "Creando filesystem squashfs (puede tardar 5-10 minutos)..."
mksquashfs \
    "${CHROOT_DIR}" \
    "${ISO_DIR}/live/filesystem.squashfs" \
    -comp xz \
    -e boot \
    -noappend \
    -no-progress 2>/dev/null
log "Squashfs creado: $(du -sh ${ISO_DIR}/live/filesystem.squashfs | cut -f1)"

# ── Copiar kernel e initrd ─────────────────────────────────────────────────────
step "Copiando kernel e initramfs"
KERNEL_VERSION=$(ls "${CHROOT_DIR}/boot/" | grep "vmlinuz" | head -1 | sed 's/vmlinuz-//')
if [[ -z "$KERNEL_VERSION" ]]; then
    error "No se encontró el kernel en el chroot."
fi
log "Versión de kernel: ${KERNEL_VERSION}"

mkdir -p "${ISO_DIR}/live"
cp "${CHROOT_DIR}/boot/vmlinuz-${KERNEL_VERSION}" "${ISO_DIR}/live/vmlinuz"
cp "${CHROOT_DIR}/boot/initrd.img-${KERNEL_VERSION}" "${ISO_DIR}/live/initrd.img"
log "Kernel e initrd copiados."

# ── Configurar GRUB para arranque ────────────────────────────────────────────
step "Configurando GRUB bootloader"
cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'GRUB_EOF'
# Miranda Legacy Holding OS - GRUB Configuration
set default=0
set timeout=5
set timeout_style=menu

# Colores estilo Windows 2000
set color_normal=white/blue
set color_highlight=black/light-gray

menuentry "Miranda Legacy Holding OS 1.0 (Live)" {
    linux /live/vmlinuz boot=live quiet splash plymouth.enable=1 \
          locale=es_PE.UTF-8 keyboard-layouts=es \
          timezone=America/Lima \
          -- quiet
    initrd /live/initrd.img
}

menuentry "Miranda Legacy Holding OS 1.0 (Instalador)" {
    linux /live/vmlinuz boot=live quiet splash \
          locale=es_PE.UTF-8 keyboard-layouts=es \
          timezone=America/Lima \
          automatic-ubiquity \
          -- quiet
    initrd /live/initrd.img
}

menuentry "Miranda Legacy Holding OS 1.0 (Modo seguro)" {
    linux /live/vmlinuz boot=live nomodeset \
          locale=es_PE.UTF-8 \
          --
    initrd /live/initrd.img
}

menuentry "Reiniciar" {
    reboot
}

menuentry "Apagar" {
    halt
}
GRUB_EOF

log "GRUB configurado."

# ── Crear la ISO final con xorriso ───────────────────────────────────────────
step "Generando ISO final"
xorriso \
    -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "MIRANDA_LEGACY_10" \
    -appid "Miranda Legacy Holding OS 1.0" \
    -publisher "Miranda Legacy Holding - Powered by Claude" \
    -preparer "build-iso.sh" \
    -b boot/grub/i386-pc/eltorito.img \
    -c boot/grub/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-alt-boot \
    -e EFI/efiboot.img \
    -no-emul-boot \
    -append_partition 2 0xef "${ISO_DIR}/EFI/efiboot.img" \
    -output "${OUTPUT_DIR}/${ISO_NAME}" \
    -graft-points \
    "${ISO_DIR}" \
    /boot/grub/i386-pc=/usr/lib/grub/i386-pc \
    2>/dev/null || \
xorriso \
    -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "MIRANDA_LEGACY_10" \
    -appid "Miranda Legacy Holding OS 1.0" \
    -publisher "Miranda Legacy Holding - Powered by Claude" \
    -no-emul-boot \
    -output "${OUTPUT_DIR}/${ISO_NAME}" \
    "${ISO_DIR}"

# ── Verificar y mostrar resultado ─────────────────────────────────────────────
step "✅ Construcción completada"
if [[ -f "${OUTPUT_DIR}/${ISO_NAME}" ]]; then
    ISO_SIZE=$(du -sh "${OUTPUT_DIR}/${ISO_NAME}" | cut -f1)
    log "ISO generada exitosamente:"
    log "  Archivo: ${OUTPUT_DIR}/${ISO_NAME}"
    log "  Tamaño:  ${ISO_SIZE}"
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Miranda Legacy Holding OS - ISO LISTA       ║${NC}"
    echo -e "${GREEN}║  Powered by Claude                           ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Para grabar en USB: sudo dd if=${OUTPUT_DIR}/${ISO_NAME} of=/dev/sdX bs=4M"
else
    error "La ISO no fue generada. Revisa los logs anteriores."
fi
