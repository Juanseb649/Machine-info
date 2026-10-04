#include <stdint.h>
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

static char *base64_encode(const unsigned char *data, size_t length)
{
    static const char alphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    size_t out_len = 4 * ((length + 2) / 3);
    char *out = malloc(out_len + 1);
    if (!out) return NULL;
    size_t w = 0;
    for (size_t i = 0; i < length; i += 3) {
        uint32_t chunk = (uint32_t)data[i] << 16;
        if (i + 1 < length) chunk |= (uint32_t)data[i + 1] << 8;
        if (i + 2 < length) chunk |= data[i + 2];
        out[w++] = alphabet[(chunk >> 18) & 63];
        out[w++] = alphabet[(chunk >> 12) & 63];
        out[w++] = i + 1 < length ? alphabet[(chunk >> 6) & 63] : '=';
        out[w++] = i + 2 < length ? alphabet[chunk & 63] : '=';
    }
    out[w] = '\0';
    return out;
}

char *mi_app_icon_png_base64(const char *icon_path, int size)
{
    const mi_software_port *port = mi_platform_software_port();
    if (!port || !port->extract_icon_png || !icon_path) return NULL;
    mi_buffer png = {0};
    if (port->extract_icon_png(icon_path, size, &png) != MI_OK) {
        mi_buffer_free(&png);
        return NULL;
    }
    char *encoded = base64_encode(png.data, png.length);
    mi_buffer_free(&png);
    return encoded;
}

int mi_launch_uninstaller(const char *command)
{
    const mi_software_port *port = mi_platform_software_port();
    if (!port || !port->launch_uninstaller) return MI_ERR_UNSUPPORTED;
    return (int)port->launch_uninstaller(command);
}

void mi_free_string(char *value)
{
    free(value);
}

const char *mi_version(void)
{
    return MACHINEINFO_VERSION;
}
