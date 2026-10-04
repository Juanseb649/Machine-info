#ifndef MI_PORTS_PLATFORM_H
#define MI_PORTS_PLATFORM_H

#include "hardware_port.h"
#include "software_port.h"

const mi_hardware_port *mi_platform_hardware_port(void);
const mi_software_port *mi_platform_software_port(void);

#endif
