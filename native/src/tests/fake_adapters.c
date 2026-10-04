#include "fake_adapters.h"

static mi_status fake_os(mi_os_info *out)
{
    mi_copy_str(out->name, sizeof(out->name), "FakeOS \"Test\"");
    mi_copy_str(out->version, sizeof(out->version), "1.0");
    mi_copy_str(out->kernel, sizeof(out->kernel), "fake-kernel");
    mi_copy_str(out->hostname, sizeof(out->hostname), "test-host");
    mi_copy_str(out->architecture, sizeof(out->architecture), "x86_64");
    out->uptime_seconds = 3600;
    return MI_OK;
}

static mi_status fake_cpu(mi_cpu_info *out)
{
    mi_copy_str(out->model, sizeof(out->model), "  Fake CPU 9000  ");
    mi_copy_str(out->vendor, sizeof(out->vendor), "FakeVendor");
    out->logical_cores = 8;
    out->physical_cores = 0;
    out->base_frequency_mhz = 3200.5;
    out->usage_percent = 140.0;
    return MI_OK;
}

static mi_status fake_memory(mi_memory_info *out)
{
    out->total_bytes = 16000;
    out->available_bytes = 4000;
    return MI_OK;
}

static mi_status fake_disks(mi_disk_list *out)
{
    mi_disk_info *a = mi_disk_list_push(out);
    mi_copy_str(a->name, sizeof(a->name), "disk0");
    a->total_bytes = 1000;
    a->free_bytes = 250;
    a->kind = MI_DISK_FIXED;

    mi_disk_info *empty = mi_disk_list_push(out);
    mi_copy_str(empty->name, sizeof(empty->name), "empty-card-reader");
    return MI_OK;
}

static mi_status fake_temperatures(mi_temperature_list *out)
{
    mi_temperature *ok = mi_temperature_list_push(out);
    mi_copy_str(ok->label, sizeof(ok->label), "CPU");
    ok->celsius = 55.5;
    ok->critical_celsius = 100;

    mi_temperature *bogus = mi_temperature_list_push(out);
    mi_copy_str(bogus->label, sizeof(bogus->label), "Broken sensor");
    bogus->celsius = 512;
    return MI_OK;
}

static mi_status fake_software(mi_package_list *out)
{
    const char *names[] = {"zsh", "Git", "git", "  ", "Bash"};
    const char *versions[] = {"5.9", "2.45", "2.45", "1", "5.2"};
    for (int i = 0; i < 5; i++) {
        mi_package *p = mi_package_list_push(out);
        mi_copy_str(p->name, sizeof(p->name), names[i]);
        mi_copy_str(p->version, sizeof(p->version), versions[i]);
        mi_copy_str(p->source, sizeof(p->source), "fake");
    }
    mi_copy_str(out->items[0].install_location, sizeof(out->items[0].install_location), "C:\\Program Files\\Git");
    mi_copy_str(out->items[0].uninstall_command, sizeof(out->items[0].uninstall_command), "\"C:\\Program Files\\Git\\unins000.exe\"");
    out->items[0].size_bytes = 2048;
    return MI_OK;
}

static mi_status unsupported_cpu(mi_cpu_info *out)
{
    (void)out;
    return MI_ERR_UNSUPPORTED;
}

static const mi_hardware_port FAKE_HARDWARE = {
    "fake", fake_os, fake_cpu, fake_memory, fake_disks, fake_temperatures,
};

static const mi_software_port FAKE_SOFTWARE = {"fake", fake_software, NULL, NULL};

static const mi_hardware_port FAILING_HARDWARE = {
    "failing", NULL, unsupported_cpu, NULL, NULL, NULL,
};

const mi_hardware_port *fake_hardware_port(void) { return &FAKE_HARDWARE; }
const mi_software_port *fake_software_port(void) { return &FAKE_SOFTWARE; }
const mi_hardware_port *failing_hardware_port(void) { return &FAILING_HARDWARE; }
