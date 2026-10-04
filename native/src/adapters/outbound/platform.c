#include "../../ports/platform.h"

#if defined(_WIN32)
const mi_hardware_port *mi_windows_hardware_port(void);
const mi_software_port *mi_windows_software_port(void);
const mi_hardware_port *mi_platform_hardware_port(void) { return mi_windows_hardware_port(); }
const mi_software_port *mi_platform_software_port(void) { return mi_windows_software_port(); }
#elif defined(__APPLE__)
const mi_hardware_port *mi_macos_hardware_port(void);
const mi_software_port *mi_macos_software_port(void);
const mi_hardware_port *mi_platform_hardware_port(void) { return mi_macos_hardware_port(); }
const mi_software_port *mi_platform_software_port(void) { return mi_macos_software_port(); }
#elif defined(__linux__)
const mi_hardware_port *mi_linux_hardware_port(void);
const mi_software_port *mi_linux_software_port(void);
const mi_hardware_port *mi_platform_hardware_port(void) { return mi_linux_hardware_port(); }
const mi_software_port *mi_platform_software_port(void) { return mi_linux_software_port(); }
#else
#error "Unsupported platform"
#endif
