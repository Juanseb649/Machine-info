#ifndef MI_PORTS_SOFTWARE_PORT_H
#define MI_PORTS_SOFTWARE_PORT_H

#include "../domain/models.h"

typedef struct {
    const char *platform;
    mi_status (*list_installed)(mi_package_list *out);
    mi_status (*extract_icon_png)(const char *icon_path, int size, mi_buffer *out);
    mi_status (*launch_uninstaller)(const char *command);
} mi_software_port;

#endif
