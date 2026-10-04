#include "report_presenter.h"

#include <time.h>

#include "json_writer.h"

#define MI_SCHEMA_VERSION 1

const char *mi_status_name(mi_status status)
{
    switch (status) {
    case MI_OK: return "ok";
    case MI_ERR_UNSUPPORTED: return "unsupported";
    case MI_ERR_IO: return "io_error";
    case MI_ERR_NO_MEMORY: return "out_of_memory";
    case MI_ERR_PERMISSION: return "permission_denied";
    default: return "unknown_error";
    }
}

static void section_header(mi_json *j, const char *name, mi_status status)
{
    mi_json_key(j, name);
    mi_json_begin_object(j);
    mi_json_kv_string(j, "status", mi_status_name(status));
    mi_json_key(j, "data");
}

static void write_os(mi_json *j, const mi_report *r)
{
    section_header(j, "os", r->os_status);
    if (r->os_status != MI_OK) {
        mi_json_null(j);
    } else {
        mi_json_begin_object(j);
        mi_json_kv_string(j, "name", r->os.name);
        mi_json_kv_string(j, "version", r->os.version);
        mi_json_kv_string(j, "kernel", r->os.kernel);
        mi_json_kv_string(j, "hostname", r->os.hostname);
        mi_json_kv_string(j, "architecture", r->os.architecture);
        mi_json_kv_u64(j, "uptimeSeconds", r->os.uptime_seconds);
        mi_json_end_object(j);
    }
    mi_json_end_object(j);
}

static void write_cpu(mi_json *j, const mi_report *r)
{
    section_header(j, "cpu", r->cpu_status);
    if (r->cpu_status != MI_OK) {
        mi_json_null(j);
    } else {
        mi_json_begin_object(j);
        mi_json_kv_string(j, "model", r->cpu.model);
        mi_json_kv_string(j, "vendor", r->cpu.vendor);
        mi_json_kv_string(j, "architecture", r->cpu.architecture);
        mi_json_kv_u64(j, "physicalCores", r->cpu.physical_cores);
        mi_json_kv_u64(j, "logicalCores", r->cpu.logical_cores);
        mi_json_kv_double(j, "baseFrequencyMhz", r->cpu.base_frequency_mhz);
        mi_json_kv_double(j, "usagePercent", r->cpu.usage_percent);
        mi_json_end_object(j);
    }
    mi_json_end_object(j);
}

static void write_memory(mi_json *j, const mi_report *r)
{
    section_header(j, "memory", r->memory_status);
    if (r->memory_status != MI_OK) {
        mi_json_null(j);
    } else {
        mi_json_begin_object(j);
        mi_json_kv_u64(j, "totalBytes", r->memory.total_bytes);
        mi_json_kv_u64(j, "availableBytes", r->memory.available_bytes);
        mi_json_kv_u64(j, "usedBytes", r->memory.used_bytes);
        mi_json_kv_u64(j, "swapTotalBytes", r->memory.swap_total_bytes);
        mi_json_kv_u64(j, "swapUsedBytes", r->memory.swap_used_bytes);
        mi_json_end_object(j);
    }
    mi_json_end_object(j);
}

static void write_disks(mi_json *j, const mi_report *r)
{
    section_header(j, "disks", r->disks_status);
    mi_json_begin_array(j);
    for (size_t i = 0; i < r->disks.count; i++) {
        const mi_disk_info *d = &r->disks.items[i];
        mi_json_begin_object(j);
        mi_json_kv_string(j, "name", d->name);
        mi_json_kv_string(j, "mountPoint", d->mount_point);
        mi_json_kv_string(j, "filesystem", d->filesystem);
        mi_json_kv_string(j, "kind", mi_disk_kind_name(d->kind));
        mi_json_kv_u64(j, "totalBytes", d->total_bytes);
        mi_json_kv_u64(j, "freeBytes", d->free_bytes);
        mi_json_kv_u64(j, "usedBytes", d->used_bytes);
        mi_json_end_object(j);
    }
    mi_json_end_array(j);
    mi_json_end_object(j);
}

static void write_temperatures(mi_json *j, const mi_report *r)
{
    section_header(j, "temperatures", r->temperatures_status);
    mi_json_begin_array(j);
    for (size_t i = 0; i < r->temperatures.count; i++) {
        const mi_temperature *t = &r->temperatures.items[i];
        mi_json_begin_object(j);
        mi_json_kv_string(j, "label", t->label);
        mi_json_kv_string(j, "source", t->source);
        mi_json_kv_double(j, "celsius", t->celsius);
        mi_json_key(j, "criticalCelsius");
        if (t->critical_celsius > 0) mi_json_double(j, t->critical_celsius);
        else mi_json_null(j);
        mi_json_end_object(j);
    }
    mi_json_end_array(j);
    mi_json_end_object(j);
}

static void write_software(mi_json *j, const mi_report *r)
{
    section_header(j, "software", r->software_status);
    mi_json_begin_array(j);
    for (size_t i = 0; i < r->software.count; i++) {
        const mi_package *p = &r->software.items[i];
        mi_json_begin_object(j);
        mi_json_kv_string(j, "name", p->name);
        mi_json_kv_string(j, "version", p->version);
        mi_json_kv_string(j, "publisher", p->publisher);
        mi_json_kv_string(j, "source", p->source);
        mi_json_end_object(j);
    }
    mi_json_end_array(j);
    mi_json_end_object(j);
}

char *mi_present_report_json(const mi_report *r)
{
    mi_json j;
    mi_json_init(&j);
    mi_json_begin_object(&j);
    mi_json_kv_u64(&j, "schemaVersion", MI_SCHEMA_VERSION);
    mi_json_kv_string(&j, "platform", r->platform);
    mi_json_kv_u64(&j, "generatedAt", (uint64_t)time(NULL));

    if (r->sections & MI_SECTION_OS) write_os(&j, r);
    if (r->sections & MI_SECTION_CPU) write_cpu(&j, r);
    if (r->sections & MI_SECTION_MEMORY) write_memory(&j, r);
    if (r->sections & MI_SECTION_DISKS) write_disks(&j, r);
    if (r->sections & MI_SECTION_TEMPERATURES) write_temperatures(&j, r);
    if (r->sections & MI_SECTION_SOFTWARE) write_software(&j, r);

    mi_json_end_object(&j);
    return mi_json_take(&j);
}

char *mi_present_error_json(const char *message)
{
    mi_json j;
    mi_json_init(&j);
    mi_json_begin_object(&j);
    mi_json_kv_u64(&j, "schemaVersion", MI_SCHEMA_VERSION);
    mi_json_kv_string(&j, "error", message);
    mi_json_end_object(&j);
    return mi_json_take(&j);
}
