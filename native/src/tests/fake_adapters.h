#ifndef MI_TESTS_FAKE_ADAPTERS_H
#define MI_TESTS_FAKE_ADAPTERS_H

#include "ports/hardware_port.h"
#include "ports/software_port.h"

const mi_hardware_port *fake_hardware_port(void);
const mi_software_port *fake_software_port(void);
const mi_hardware_port *failing_hardware_port(void);

#endif
