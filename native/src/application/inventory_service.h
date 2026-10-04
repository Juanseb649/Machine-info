#ifndef MI_APPLICATION_INVENTORY_SERVICE_H
#define MI_APPLICATION_INVENTORY_SERVICE_H

#include "../ports/hardware_port.h"
#include "../ports/software_port.h"

typedef enum {
    MI_SECTION_OS = 1u << 0,
    MI_SECTION_CPU = 1u << 1,
    MI_SECTION_MEMORY = 1u << 2,
    MI_SECTION_DISKS = 1u << 3,
    MI_SECTION_TEMPERATURES = 1u << 4,
    MI_SECTION_SOFTWARE = 1u << 5,
    MI_SECTION_HARDWARE = (1u << 5) - 1,
    MI_SECTION_ALL = (1u << 6) - 1
} mi_section;

typedef struct {
    const mi_hardware_port *hardware;
    const mi_software_port *software;
} mi_inventory_service;

typedef struct {
    unsigned sections;
    const char *platform;

    mi_status os_status;
    mi_os_info os;

    mi_status cpu_status;
    mi_cpu_info cpu;

    mi_status memory_status;
    mi_memory_info memory;

    mi_status disks_status;
    mi_disk_list disks;

    mi_status temperatures_status;
    mi_temperature_list temperatures;

    mi_status software_status;
    mi_package_list software;
} mi_report;

void mi_inventory_init(mi_inventory_service *svc,
                       const mi_hardware_port *hardware,
                       const mi_software_port *software);

void mi_inventory_collect(const mi_inventory_service *svc, unsigned sections, mi_report *out);

void mi_report_free(mi_report *report);

unsigned mi_section_from_name(const char *name);

#endif
