# 🖥️ Miranda Legacy Holding OS

**Powered by Claude - Anthropic**

> *"El pasado nunca muere, simplemente se reoptimiza para el futuro."*

Sistema operativo retro-futurista basado en **Debian 12 Bookworm 32-bit**, optimizado para **HP Mini 110-1a** con estética visual **Windows 2000**.

---

## 📋 Especificaciones

| Aspecto | Especificación |
|---------|----------------|
| SO Base | Debian 12 Bookworm (i386 / 32-bit) |
| Escritorio | XFCE 4.18+ |
| Kernel | Linux 6.x con soporte PAE |
| Hardware | HP Mini 110-1a (Intel Atom N270) |
| RAM mínima | 512 MB (recomendado 1 GB+) |
| Almacenamiento | 5-8 GB para instalación completa |
| Tamaño ISO | ~1.8-2.2 GB |
| Compatibilidad | Wine 9.x (software Windows .exe) |
| Idioma | Español (+ English) |
| Licencia | GPL v2/v3 |

---

## 📦 Software incluido

- **Navegador**: Firefox ESR 32-bit + uBlock Origin + HTTPS Everywhere
- **Correo**: Thunderbird
- **Oficina**: Abiword (compatible con .doc, .odt, .docx)
- **Editor de texto**: Mousepad (estilo Notepad Windows 2000)
- **Archivos**: Thunar (vista estilo Windows Explorer)
- **Imágenes**: Ristretto (visor ligero)
- **Compresión**: File Roller
- **Calendario**: Orage
- **Calculadora**: GNOME Calculator (temático retro)
- **Wine 9.x**: Para ejecutar software clásico de Windows
- **Terminal**: xfce4-terminal
- **Sistema**: Gestor de energía, screensaver, monitor de batería

---

## 🎨 Estética Windows 2000

- Panel inferior gris clásico `#d4d0c8`
- Barra de título azul degradado
- Bordes de ventana biselados 3D
- Fuente Liberation Sans (simulando MS Sans Serif)
- Cursor Windows 2000 negro
- Iconos estilo retro 32x32
- Wallpaper gradiente azul clásico
- Sonidos del sistema Windows 2000

---

## ⌨️ Atajos de Teclado (estilo Windows)

| Atajo | Acción |
|-------|--------|
| `Win + L` | Bloquear pantalla |
| `Win + D` | Mostrar escritorio |
| `Win + E` | Explorador de archivos |
| `Alt + F4` | Cerrar ventana |
| `Alt + Tab` | Cambiar ventanas |
| `Ctrl + Alt + T` | Abrir terminal |
| `Ctrl + Alt + Del` | Cerrar sesión / Apagar |

---

## 🔨 Construir la ISO

### Con GitHub Actions (recomendado)

1. Hacer fork de este repositorio
2. Ir a **Actions** → **Build Miranda Legacy Holding OS ISO**
3. Hacer clic en **Run workflow**
4. Cuando termine, la ISO se publicará automáticamente en **Releases**

### Localmente (requiere Linux con root)

```bash
git clone https://github.com/TU-USUARIO/miranda-legacy-os.git
cd miranda-legacy-os
sudo bash scripts/build-iso.sh
# La ISO quedará en: output/miranda-legacy-holding-os-1.0-i386.iso
```

**Requisitos para build local:**
- Linux (Ubuntu 22.04+ recomendado)
- Al menos 15 GB de espacio libre
- Conexión a internet
- Acceso root (sudo)

---

## 💿 Instalar en HP Mini 110-1a

### 1. Grabar en USB
```bash
# Linux/Mac
sudo dd if=miranda-legacy-holding-os-1.0-i386.iso of=/dev/sdX bs=4M status=progress

# Windows: usar Rufus o balenaEtcher
```

### 2. Arrancar desde USB
- Encender HP Mini 110-1a
- Presionar `Esc` o `F9` para menú de boot
- Seleccionar el USB

### 3. Instalar
- Usar el modo Live para probar primero
- Doble clic en el instalador **Calamares** del escritorio
- Seguir los 6 pasos del asistente

---

## ⚙️ Post-instalación

Ejecutar en terminal para personalizar:
```bash
miranda-tweaks
```

Opciones disponibles:
- Cambiar fondo de pantalla
- Activar/desactivar sonidos
- Ajustar resolución
- Instalar software adicional
- Configurar Wine

---

## 🏗️ Estructura del Repositorio

```
miranda-legacy-os/
├── .github/
│   └── workflows/
│       └── build-iso.yml      # GitHub Actions CI/CD
├── scripts/
│   └── build-iso.sh           # Script principal de build
├── config/
│   ├── preseed/               # Configuración preinstalación Debian
│   ├── plymouth/              # Tema de boot splash
│   ├── xfce-theme/            # Tema visual Windows 2000
│   └── lightdm/               # Pantalla de login
├── docs/
│   └── (documentación)
└── README.md
```

---

## 📄 Licencia

GPL v2/v3 — Open Source

**Creado con Claude (Anthropic)**
