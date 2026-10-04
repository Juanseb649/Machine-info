Primera versión pública de **Machine Info**: hardware y software de tu equipo, de un vistazo.

## Novedades
- Información de **sistema, CPU, memoria, almacenamiento y temperaturas** con medidores y refresco en vivo.
- **Software instalado** con logo, versión, editor, ubicación, tecnología detectada y desinstalación.
- Diseño *liquid glass* con modo día/noche, barra lateral, ajustes y tutorial inicial.
- Nuevo **logo**, íconos de aplicación y pantalla de inicio animada mientras se recopila la información.
- Núcleo en C con arquitectura hexagonal que usa las APIs nativas de cada sistema.

## Descargas
| Sistema | Archivo | Cómo abrirlo |
|---|---|---|
| Windows 10/11 (x64) | `MachineInfo-windows-x64.zip` | Descomprime y ejecuta `machine_info.exe`. Si aparece SmartScreen: *Más información → Ejecutar de todas formas*. |
| macOS 10.15+ (Intel y Apple Silicon) | `MachineInfo-macos-universal.dmg` | Arrastra **Machine Info** a Aplicaciones. La primera vez: clic derecho → *Abrir*. |
| Linux x64 | `MachineInfo-linux-x64.tar.gz` | `tar -xzf MachineInfo-linux-x64.tar.gz && ./machine-info/machine_info` (requiere GTK 3). |

## Notas
- Las compilaciones no están firmadas digitalmente, por eso Windows y macOS muestran una advertencia la primera vez.
- En Windows, algunas temperaturas solo están disponibles ejecutando la app como administrador.
