#ifndef MI_PORTS_HARDWARE_PORT_H
#define MI_PORTS_HARDWARE_PORT_H

#include "../domain/models.h"

typedef struct {
    const char *platform;
    mi_status (*read_os)(mi_os_info *out);
    mi_status (*read_cpu)(mi_cpu_info *out);
    mi_status (*read_memory)(mi_memory_info *out);
    mi_status (*read_disks)(mi_disk_list *out);
    mi_status (*read_temperatures)(mi_temperature_list *out);
} mi_hardware_port;

#endif
