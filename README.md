# Machine Info

Aplicación de escritorio multiplataforma (Windows, macOS, Linux) que muestra el hardware del equipo
(CPU, RAM, almacenamiento, temperaturas, sistema operativo) y el software instalado, organizado en pestañas.

- **Núcleo**: C11, arquitectura hexagonal, usa solo las APIs nativas de cada sistema operativo.
- **Interfaz**: Flutter desktop, conectado al núcleo con `dart:ffi` a través de una librería compartida que devuelve JSON.
- **Diseño**: estilo *liquid glass* (paneles translúcidos con desenfoque), modo día/noche automático (según el sistema o
  la hora) o fijo desde **Ajustes**, y un tutorial guiado en el primer inicio.

## Estructura

```
machine-info/
├── native/                         Plugin FFI de Flutter (machine_info_native)
│   ├── src/                        ← Núcleo en C (compila solo con CMake)
│   │   ├── include/machineinfo/    API pública: mi_collect_json, mi_free_string, mi_version
│   │   ├── domain/                 Entidades: mi_cpu_info, mi_disk_info, mi_package…
│   │   ├── ports/                  Puertos de salida: mi_hardware_port, mi_software_port
│   │   ├── application/            Caso de uso: inventory_service (normaliza, ordena, deduplica)
│   │   ├── adapters/
│   │   │   ├── inbound/            c_api.c (FFI), cli/, json/ (presentador JSON)
│   │   │   └── outbound/           linux/, windows/, macos/  ← un adaptador por SO
│   │   └── tests/                  Pruebas del dominio con adaptadores falsos
│   ├── lib/                        Bindings Dart (dart:ffi)
│   ├── linux/ windows/ macos/      Compilan y empaquetan la librería con la app
└── app/                            App Flutter
    └── lib/src/
        ├── domain/                 Entidades + puerto MachineInfoRepository
        ├── application/            InventoryController
        ├── infrastructure/         FfiMachineInfoRepository + ReportMapper (JSON → entidades)
        └── presentation/           Barra lateral + secciones: Sistema, CPU, Memoria, Almacenamiento,
                                    Temperaturas, Software, Ajustes · theme/ (liquid glass) · onboarding/
```

### Flujo

```
Flutter (presentación) → InventoryController → MachineInfoRepository (puerto)
   → FfiMachineInfoRepository ──dart:ffi──► mi_collect_json("hardware")
      → inventory_service (aplicación) → mi_hardware_port / mi_software_port (puertos)
         → adaptador del SO (Linux /proc /sys · Windows Win32/Registro/WMI · macOS sysctl/IOKit/CoreFoundation)
      ← report_presenter → JSON
```

La recolección corre en un `Isolate` para no bloquear la interfaz.

### Software: logos, detalle y desinstalación

Cada programa trae `installLocation`, `iconPath`, `uninstallCommand`, `installDate` y `sizeBytes`.

| | Windows | Linux | macOS |
|---|---|---|---|
| Logo | `DisplayIcon` (o el .exe principal) → `mi_app_icon_png_base64` (Shell + GDI → PNG) | Icono del `.desktop` del paquete (hicolor / pixmaps / snap / flatpak) | `CFBundleIconFile` (.icns, se extrae el PNG en Dart) |
| Ubicación | `InstallLocation` (o carpeta del icono) | `/opt/...`, binario en `/usr/bin`, `/snap/...`, flatpak | Ruta del `.app`, Cellar/Caskroom |
| Desinstalar | `UninstallString` vía `ShellExecuteEx` (`mi_launch_uninstaller`, MSI `/I` → `/X`) | `pkexec apt-get remove`, `dnf`, `pacman`, `flatpak`, `snap` | Finder → Papelera, `brew uninstall` |

El **lenguaje/tecnología** se detecta en Dart al abrir el detalle, revisando los archivos instalados
(Electron, Flutter, .NET, Java, Python, Qt, Unity, CEF, GTK…) y, si hace falta, el ejecutable principal
(Go, Rust, .NET Framework, scripts con *shebang*, binario nativo C/C++).

## Fuentes de datos por sistema

| Dato | Linux | Windows | macOS |
|---|---|---|---|
| SO | `/etc/os-release`, `uname`, `/proc/uptime` | `RtlGetVersion`, registro `CurrentVersion` | `sysctl kern.osproductversion`, `kern.boottime` |
| CPU | `/proc/cpuinfo`, `/proc/stat`, `cpufreq` | registro `CentralProcessor`, `cpuid`, `GetLogicalProcessorInformationEx`, `GetSystemTimes` | `sysctl machdep.cpu.*`, `host_statistics` |
| RAM | `/proc/meminfo` | `GlobalMemoryStatusEx` | `hw.memsize`, `host_statistics64`, `vm.swapusage` |
| Discos | `/proc/self/mounts` + `statvfs`, `/sys/block/*/removable` | `GetLogicalDriveStrings`, `GetDiskFreeSpaceEx`, `GetVolumeInformation` | `getmntinfo`, DiskArbitration |
| Temperaturas | `/sys/class/hwmon`, `/sys/class/thermal` | WMI `ThermalZoneInformation` / `MSAcpi_ThermalZoneTemperature` | SMC vía IOKit (Intel y Apple Silicon) |
| Software | dpkg, rpm, pacman, flatpak, snap | Registro `Uninstall` (HKLM x64/x86 + HKCU) | `/Applications` (Info.plist), Homebrew |

## Requisitos

- Flutter 3.27 o superior con soporte de escritorio habilitado (`flutter doctor`).
- CMake 3.16 o superior.
- **Windows**: Visual Studio 2022 con la carga de trabajo *Desarrollo para el escritorio con C++*.
- **Linux**: `clang cmake ninja-build pkg-config libgtk-3-dev`.
- **macOS**: Xcode + CocoaPods.

## Primeros pasos

### 1. Probar el núcleo en C (opcional)

```bash
cd native/src
cmake -S . -B build
cmake --build build --config Release
ctest --test-dir build -C Release
./build/machineinfo-cli hardware        # Windows: build\Release\machineinfo-cli.exe hardware
```

Secciones: `os`, `cpu`, `memory`, `disks`, `temperatures`, `software`, `hardware`, `all`.

### 2. Generar los runners de escritorio (solo la primera vez)

```bash
cd app
flutter create --platforms=windows,linux,macos --project-name machine_info .
```

No sobrescribe `lib/` ni `test/`; solo agrega las carpetas `windows/`, `linux/` y `macos/`.

**Solo macOS:** desactiva el sandbox para poder leer `/Applications`, el SMC y Homebrew. En
`macos/Runner/DebugProfile.entitlements` y `macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```

### 3. Ejecutar

```bash
flutter pub get
flutter test
flutter run -d windows   # o -d linux / -d macos
```

Flutter compila el núcleo en C automáticamente (CMake en Windows/Linux, CocoaPods en macOS) y empaqueta
`machineinfo.dll` / `libmachineinfo.so` / `machine_info_native.framework` junto a la app.

Para usar una librería compilada a mano, define la variable de entorno `MACHINEINFO_LIB` con su ruta.

## Notas

- **Temperaturas en Windows**: muchos equipos no exponen sensores por WMI; `MSAcpi_ThermalZoneTemperature`
  requiere ejecutar como administrador. Si no hay datos, la pestaña lo indica.
- **macOS**: el adaptador se escribió contra las APIs documentadas pero aún no se ha compilado en un Mac.
- Formato JSON: cada sección trae `status` (`ok`, `unsupported`, `permission_denied`, `io_error`) y `data`.

## Atajos

- `Ctrl + R` actualizar · `Ctrl + 1…7` cambiar de sección · flechas / `Esc` dentro del tutorial.

## Ideas siguientes

- Apps de Microsoft Store (AppX) en Windows y salud SMART de los discos.
- GPU y batería como nuevos puertos/adaptadores.
- Exportar el reporte a JSON/PDF desde la interfaz.
