#include "inventory_service.h"

#include <ctype.h>
#include <stdlib.h>
#include <string.h>

void mi_inventory_init(mi_inventory_service *svc,
                       const mi_hardware_port *hardware,
                       const mi_software_port *software)
{
    svc->hardware = hardware;
    svc->software = software;
}

static int ci_compare(const char *a, const char *b)
{
    for (;; a++, b++) {
        int ca = tolower((unsigned char)*a);
        int cb = tolower((unsigned char)*b);
        if (ca != cb || ca == '\0') return ca - cb;
    }
}

static int compare_packages(const void *lhs, const void *rhs)
{
    const mi_package *a = lhs;
    const mi_package *b = rhs;
    int by_name = ci_compare(a->name, b->name);
    if (by_name != 0) return by_name;
    int by_version = strcmp(a->version, b->version);
    if (by_version != 0) return by_version;
    return strcmp(a->source, b->source);
}

static void normalize_packages(mi_package_list *list)
{
    size_t write = 0;
    for (size_t i = 0; i < list->count; i++) {
        mi_trim(list->items[i].name);
        mi_trim(list->items[i].version);
        mi_trim(list->items[i].publisher);
        if (list->items[i].name[0] == '\0') continue;
        list->items[write++] = list->items[i];
    }
    list->count = write;

    if (list->count < 2) return;
    qsort(list->items, list->count, sizeof(mi_package), compare_packages);

    write = 1;
    for (size_t i = 1; i < list->count; i++) {
        mi_package *prev = &list->items[write - 1];
        mi_package *cur = &list->items[i];
        int duplicate = ci_compare(prev->name, cur->name) == 0 &&
                        strcmp(prev->version, cur->version) == 0 &&
                        strcmp(prev->source, cur->source) == 0;
        if (!duplicate) list->items[write++] = *cur;
    }
    list->count = write;
}

static void normalize_disks(mi_disk_list *list)
{
    size_t write = 0;
    for (size_t i = 0; i < list->count; i++) {
        mi_disk_info *d = &list->items[i];
        if (d->total_bytes == 0) continue;
        if (d->free_bytes > d->total_bytes) d->free_bytes = d->total_bytes;
        if (d->used_bytes == 0 || d->used_bytes > d->total_bytes) d->used_bytes = d->total_bytes - d->free_bytes;
        list->items[write++] = *d;
    }
    list->count = write;
}

static void normalize_memory(mi_memory_info *m)
{
    if (m->available_bytes > m->total_bytes) m->available_bytes = m->total_bytes;
    if (m->used_bytes == 0 || m->used_bytes > m->total_bytes) m->used_bytes = m->total_bytes - m->available_bytes;
    if (m->swap_used_bytes > m->swap_total_bytes) m->swap_used_bytes = m->swap_total_bytes;
}

static void normalize_cpu(mi_cpu_info *c)
{
    if (c->usage_percent < 0) c->usage_percent = 0;
    if (c->usage_percent > 100) c->usage_percent = 100;
    if (c->physical_cores == 0) c->physical_cores = c->logical_cores;
    mi_trim(c->model);
}

static void normalize_temperatures(mi_temperature_list *list)
{
    size_t write = 0;
    for (size_t i = 0; i < list->count; i++) {
        mi_temperature *t = &list->items[i];
        if (t->celsius <= -50.0 || t->celsius >= 150.0) continue;
        list->items[write++] = *t;
    }
    list->count = write;
}

#define RUN(port, fn, arg) ((port) && (port)->fn ? (port)->fn(arg) : MI_ERR_UNSUPPORTED)

void mi_inventory_collect(const mi_inventory_service *svc, unsigned sections, mi_report *out)
{
    memset(out, 0, sizeof(*out));
    out->sections = sections & MI_SECTION_ALL;
    out->platform = svc->hardware ? svc->hardware->platform : "unknown";

    if (sections & MI_SECTION_OS) {
        out->os_status = RUN(svc->hardware, read_os, &out->os);
    }
    if (sections & MI_SECTION_CPU) {
        out->cpu_status = RUN(svc->hardware, read_cpu, &out->cpu);
        if (out->cpu_status == MI_OK) normalize_cpu(&out->cpu);
    }
    if (sections & MI_SECTION_MEMORY) {
        out->memory_status = RUN(svc->hardware, read_memory, &out->memory);
        if (out->memory_status == MI_OK) normalize_memory(&out->memory);
    }
    if (sections & MI_SECTION_DISKS) {
        out->disks_status = RUN(svc->hardware, read_disks, &out->disks);
        normalize_disks(&out->disks);
    }
    if (sections & MI_SECTION_TEMPERATURES) {
        out->temperatures_status = RUN(svc->hardware, read_temperatures, &out->temperatures);
        normalize_temperatures(&out->temperatures);
    }
    if (sections & MI_SECTION_SOFTWARE) {
        out->software_status = RUN(svc->software, list_installed, &out->software);
        normalize_packages(&out->software);
    }
}

void mi_report_free(mi_report *report)
{
    mi_disk_list_free(&report->disks);
    mi_temperature_list_free(&report->temperatures);
    mi_package_list_free(&report->software);
}

unsigned mi_section_from_name(const char *name)
{
    static const struct {
        const char *name;
        unsigned mask;
    } table[] = {
        {"os", MI_SECTION_OS},
        {"cpu", MI_SECTION_CPU},
        {"memory", MI_SECTION_MEMORY},
        {"disks", MI_SECTION_DISKS},
        {"temperatures", MI_SECTION_TEMPERATURES},
        {"software", MI_SECTION_SOFTWARE},
        {"hardware", MI_SECTION_HARDWARE},
        {"all", MI_SECTION_ALL},
    };
    if (!name || !*name) return MI_SECTION_ALL;
    for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++) {
        if (ci_compare(name, table[i].name) == 0) return table[i].mask;
    }
    return 0;
}
