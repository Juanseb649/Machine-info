#include <stdlib.h>

#include "machineinfo/machineinfo.h"

#include "../../application/inventory_service.h"
#include "../../ports/platform.h"
#include "json/report_presenter.h"

#ifndef MACHINEINFO_VERSION
#define MACHINEINFO_VERSION "0.1.0"
#endif

char *mi_collect_json(const char *section)
{
    unsigned mask = mi_section_from_name(section);
    if (mask == 0) return mi_present_error_json("unknown section");

    mi_inventory_service service;
    mi_inventory_init(&service, mi_platform_hardware_port(), mi_platform_software_port());

    mi_report report;
    mi_inventory_collect(&service, mask, &report);
    char *json = mi_present_report_json(&report);
    mi_report_free(&report);
    return json;
}

void mi_free_string(char *value)
{
    free(value);
}

const char *mi_version(void)
{
    return MACHINEINFO_VERSION;
}
