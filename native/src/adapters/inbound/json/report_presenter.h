#ifndef MI_REPORT_PRESENTER_H
#define MI_REPORT_PRESENTER_H

#include "../../../application/inventory_service.h"

char *mi_present_report_json(const mi_report *report);
char *mi_present_error_json(const char *message);
const char *mi_status_name(mi_status status);

#endif
