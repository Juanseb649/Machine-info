#define _GNU_SOURCE
#include <dirent.h>
#include <mntent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/statvfs.h>
#include <sys/utsname.h>
#include <time.h>
#include <unistd.h>

#include "../../../ports/hardware_port.h"
#include "../common/text_utils.h"

typedef struct {
    mi_os_info *os;
    char version_id[MI_STR_SMALL];
} os_release_ctx;

static void unquote(char *value)
{
    size_t len = strlen(value);
    if (len >= 2 && (value[0] == '"' || value[0] == '\'') && value[len - 1] == value[0]) {
        memmove(value, value + 1, len - 2);
        value[len - 2] = '\0';
    }
}

static void on_os_release(char *line, void *ctx)
{
    os_release_ctx *c = ctx;
    char *key, *value;
    if (!mi_split_key_value(line, '=', &key, &value)) return;
    unquote(value);
    if (strcmp(key, "PRETTY_NAME") == 0) mi_copy_str(c->os->name, sizeof(c->os->name), value);
    else if (strcmp(key, "NAME") == 0 && c->os->name[0] == '\0') mi_copy_str(c->os->name, sizeof(c->os->name), value);
    else if (strcmp(key, "VERSION_ID") == 0) mi_copy_str(c->version_id, sizeof(c->version_id), value);
}

static mi_status linux_read_os(mi_os_info *out)
{
    os_release_ctx ctx = {.os = out};
    if (mi_read_file_lines("/etc/os-release", on_os_release, &ctx) < 0)
        mi_read_file_lines("/usr/lib/os-release", on_os_release, &ctx);
    if (out->name[0] == '\0') mi_copy_str(out->name, sizeof(out->name), "Linux");
    mi_copy_str(out->version, sizeof(out->version), ctx.version_id);

    struct utsname u;
    if (uname(&u) == 0) {
        mi_copy_str(out->kernel, sizeof(out->kernel), u.release);
        mi_copy_str(out->architecture, sizeof(out->architecture), u.machine);
        mi_copy_str(out->hostname, sizeof(out->hostname), u.nodename);
    }

    char uptime[64];
    if (mi_read_first_line("/proc/uptime", uptime, sizeof(uptime)) == 0)
        out->uptime_seconds = (uint64_t)strtod(uptime, NULL);
    return MI_OK;
}

#define MAX_CORE_IDS 1024

typedef struct {
    mi_cpu_info *cpu;
    int physical_id;
    long core_keys[MAX_CORE_IDS];
    size_t core_key_count;
    double mhz;
} cpuinfo_ctx;

static void remember_core(cpuinfo_ctx *c, long key)
{
    for (size_t i = 0; i < c->core_key_count; i++)
        if (c->core_keys[i] == key) return;
    if (c->core_key_count < MAX_CORE_IDS) c->core_keys[c->core_key_count++] = key;
}

static void on_cpuinfo(char *line, void *ctx)
{
    cpuinfo_ctx *c = ctx;
    char *key, *value;
    if (!mi_split_key_value(line, ':', &key, &value)) return;

    if (strcmp(key, "model name") == 0 && c->cpu->model[0] == '\0')
        mi_copy_str(c->cpu->model, sizeof(c->cpu->model), value);
    else if ((strcmp(key, "Model") == 0 || strcmp(key, "Hardware") == 0) && c->cpu->model[0] == '\0')
        mi_copy_str(c->cpu->model, sizeof(c->cpu->model), value);
    else if (strcmp(key, "vendor_id") == 0 && c->cpu->vendor[0] == '\0')
        mi_copy_str(c->cpu->vendor, sizeof(c->cpu->vendor), value);
    else if (strcmp(key, "CPU implementer") == 0 && c->cpu->vendor[0] == '\0')
        mi_copy_str(c->cpu->vendor, sizeof(c->cpu->vendor), value);
    else if (strcmp(key, "cpu MHz") == 0 && c->mhz == 0)
        c->mhz = strtod(value, NULL);
    else if (strcmp(key, "physical id") == 0)
        c->physical_id = atoi(value);
    else if (strcmp(key, "core id") == 0)
        remember_core(c, ((long)c->physical_id << 16) | atol(value));
}

typedef struct {
    unsigned long long idle;
    unsigned long long total;
} cpu_times;

static int read_cpu_times(cpu_times *t)
{
    FILE *f = fopen("/proc/stat", "r");
    if (!f) return -1;
    unsigned long long v[10] = {0};
    int n = fscanf(f, "cpu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu",
                   &v[0], &v[1], &v[2], &v[3], &v[4], &v[5], &v[6], &v[7], &v[8], &v[9]);
    fclose(f);
    if (n < 4) return -1;
    t->idle = v[3] + v[4];
    t->total = 0;
    for (int i = 0; i < 8; i++) t->total += v[i];
    return 0;
}

static double sample_cpu_usage(void)
{
    cpu_times a, b;
    if (read_cpu_times(&a) != 0) return 0;
    struct timespec pause = {0, 250 * 1000 * 1000};
    nanosleep(&pause, NULL);
    if (read_cpu_times(&b) != 0) return 0;
    unsigned long long total = b.total - a.total;
    unsigned long long idle = b.idle - a.idle;
    if (total == 0) return 0;
    return 100.0 * (double)(total - idle) / (double)total;
}

static double read_khz_file(const char *path)
{
    char line[64];
    if (mi_read_first_line(path, line, sizeof(line)) != 0) return 0;
    return strtod(line, NULL) / 1000.0;
}

static mi_status linux_read_cpu(mi_cpu_info *out)
{
    cpuinfo_ctx ctx = {.cpu = out};
    if (mi_read_file_lines("/proc/cpuinfo", on_cpuinfo, &ctx) < 0) return MI_ERR_IO;

    long online = sysconf(_SC_NPROCESSORS_ONLN);
    out->logical_cores = online > 0 ? (uint32_t)online : 1;
    out->physical_cores = (uint32_t)ctx.core_key_count;

    out->base_frequency_mhz = read_khz_file("/sys/devices/system/cpu/cpu0/cpufreq/base_frequency");
    if (out->base_frequency_mhz == 0)
        out->base_frequency_mhz = read_khz_file("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq");
    if (out->base_frequency_mhz == 0) out->base_frequency_mhz = ctx.mhz;

    struct utsname u;
    if (uname(&u) == 0) mi_copy_str(out->architecture, sizeof(out->architecture), u.machine);
    if (out->model[0] == '\0') mi_copy_str(out->model, sizeof(out->model), out->architecture);

    out->usage_percent = sample_cpu_usage();
    return MI_OK;
}

typedef struct {
    uint64_t total, available, free, swap_total, swap_free;
    int has_available;
} meminfo_ctx;

static void on_meminfo(char *line, void *ctx)
{
    meminfo_ctx *m = ctx;
    char *key, *value;
    if (!mi_split_key_value(line, ':', &key, &value)) return;
    uint64_t bytes = strtoull(value, NULL, 10) * 1024ULL;
    if (strcmp(key, "MemTotal") == 0) m->total = bytes;
    else if (strcmp(key, "MemAvailable") == 0) { m->available = bytes; m->has_available = 1; }
    else if (strcmp(key, "MemFree") == 0) m->free = bytes;
    else if (strcmp(key, "SwapTotal") == 0) m->swap_total = bytes;
    else if (strcmp(key, "SwapFree") == 0) m->swap_free = bytes;
}

static mi_status linux_read_memory(mi_memory_info *out)
{
    meminfo_ctx m = {0};
    if (mi_read_file_lines("/proc/meminfo", on_meminfo, &m) < 0) return MI_ERR_IO;
    out->total_bytes = m.total;
    out->available_bytes = m.has_available ? m.available : m.free;
    out->used_bytes = m.total - out->available_bytes;
    out->swap_total_bytes = m.swap_total;
    out->swap_used_bytes = m.swap_total - m.swap_free;
    return MI_OK;
}

static int is_network_fs(const char *fs)
{
    static const char *types[] = {"nfs", "nfs4", "cifs", "smbfs", "smb3", "sshfs", "fuse.sshfs", "9p", "afs", NULL};
    for (int i = 0; types[i]; i++)
        if (strcmp(fs, types[i]) == 0) return 1;
    return 0;
}

static int is_ignored_fs(const char *fs)
{
    static const char *types[] = {"squashfs", "overlay", "tmpfs", "devtmpfs", "ramfs", "autofs", NULL};
    for (int i = 0; types[i]; i++)
        if (strcmp(fs, types[i]) == 0) return 1;
    return 0;
}

static void block_device_name(const char *device, char *out, size_t out_size)
{
    const char *base = strrchr(device, '/');
    base = base ? base + 1 : device;
    mi_copy_str(out, out_size, base);

    char path[512];
    snprintf(path, sizeof(path), "/sys/class/block/%s/partition", out);
    if (access(path, F_OK) != 0) return;

    size_t len = strlen(out);
    while (len > 0 && out[len - 1] >= '0' && out[len - 1] <= '9') out[--len] = '\0';
    if (len > 1 && out[len - 1] == 'p' && (mi_starts_with(out, "nvme") || mi_starts_with(out, "mmcblk")))
        out[--len] = '\0';
}

static mi_disk_kind classify_disk(const char *device, const char *fs)
{
    if (is_network_fs(fs)) return MI_DISK_NETWORK;
    if (strcmp(fs, "iso9660") == 0 || strcmp(fs, "udf") == 0) return MI_DISK_OPTICAL;
    if (!mi_starts_with(device, "/dev/")) return MI_DISK_UNKNOWN;

    char parent[128], path[512], value[16];
    block_device_name(device, parent, sizeof(parent));
    snprintf(path, sizeof(path), "/sys/block/%s/removable", parent);
    if (mi_read_first_line(path, value, sizeof(value)) == 0 && value[0] == '1') return MI_DISK_REMOVABLE;
    return MI_DISK_FIXED;
}

static int already_listed(const mi_disk_list *list, const char *device)
{
    for (size_t i = 0; i < list->count; i++)
        if (strcmp(list->items[i].name, device) == 0) return 1;
    return 0;
}

static mi_status linux_read_disks(mi_disk_list *out)
{
    FILE *mounts = setmntent("/proc/self/mounts", "r");
    if (!mounts) return MI_ERR_IO;

    struct mntent *e;
    while ((e = getmntent(mounts)) != NULL) {
        int is_block = mi_starts_with(e->mnt_fsname, "/dev/") && !mi_starts_with(e->mnt_fsname, "/dev/loop");
        if (!is_block && !is_network_fs(e->mnt_type)) continue;
        if (is_ignored_fs(e->mnt_type)) continue;
        if (already_listed(out, e->mnt_fsname)) continue;

        struct statvfs s;
        if (statvfs(e->mnt_dir, &s) != 0) continue;

        mi_disk_info *d = mi_disk_list_push(out);
        if (!d) break;
        mi_copy_str(d->name, sizeof(d->name), e->mnt_fsname);
        mi_copy_str(d->mount_point, sizeof(d->mount_point), e->mnt_dir);
        mi_copy_str(d->filesystem, sizeof(d->filesystem), e->mnt_type);
        d->kind = classify_disk(e->mnt_fsname, e->mnt_type);
        d->total_bytes = (uint64_t)s.f_blocks * s.f_frsize;
        d->free_bytes = (uint64_t)s.f_bavail * s.f_frsize;
        d->used_bytes = (uint64_t)(s.f_blocks - s.f_bfree) * s.f_frsize;
    }
    endmntent(mounts);
    return MI_OK;
}

static double read_millidegrees(const char *path)
{
    char line[64];
    if (mi_read_first_line(path, line, sizeof(line)) != 0) return -1000;
    return strtod(line, NULL) / 1000.0;
}

static void read_hwmon_device(const char *dir, mi_temperature_list *out)
{
    char path[1024], chip[MI_STR_SMALL] = "hwmon";
    snprintf(path, sizeof(path), "%s/name", dir);
    mi_read_first_line(path, chip, sizeof(chip));

    for (int i = 1; i <= 32; i++) {
        snprintf(path, sizeof(path), "%s/temp%d_input", dir, i);
        double celsius = read_millidegrees(path);
        if (celsius <= -1000) continue;

        mi_temperature *t = mi_temperature_list_push(out);
        if (!t) return;

        char label[MI_STR_SMALL * 2] = "";
        snprintf(path, sizeof(path), "%s/temp%d_label", dir, i);
        if (mi_read_first_line(path, label, sizeof(label)) != 0) snprintf(label, sizeof(label), "temp%d", i);
        snprintf(t->label, sizeof(t->label), "%s %s", chip, label);
        mi_copy_str(t->source, sizeof(t->source), "hwmon");
        t->celsius = celsius;

        snprintf(path, sizeof(path), "%s/temp%d_crit", dir, i);
        double crit = read_millidegrees(path);
        t->critical_celsius = crit > 0 ? crit : 0;
    }
}

static void read_hwmon(mi_temperature_list *out)
{
    DIR *d = opendir("/sys/class/hwmon");
    if (!d) return;
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        if (e->d_name[0] == '.') continue;
        char dir[512];
        snprintf(dir, sizeof(dir), "/sys/class/hwmon/%s", e->d_name);
        read_hwmon_device(dir, out);
    }
    closedir(d);
}

static void read_thermal_zones(mi_temperature_list *out)
{
    DIR *d = opendir("/sys/class/thermal");
    if (!d) return;
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        if (!mi_starts_with(e->d_name, "thermal_zone")) continue;
        char path[512];
        snprintf(path, sizeof(path), "/sys/class/thermal/%s/temp", e->d_name);
        double celsius = read_millidegrees(path);
        if (celsius <= -1000) continue;

        mi_temperature *t = mi_temperature_list_push(out);
        if (!t) break;
        snprintf(path, sizeof(path), "/sys/class/thermal/%s/type", e->d_name);
        if (mi_read_first_line(path, t->label, sizeof(t->label)) != 0)
            mi_copy_str(t->label, sizeof(t->label), e->d_name);
        mi_copy_str(t->source, sizeof(t->source), "thermal_zone");
        t->celsius = celsius;
    }
    closedir(d);
}

static mi_status linux_read_temperatures(mi_temperature_list *out)
{
    read_hwmon(out);
    if (out->count == 0) read_thermal_zones(out);
    return out->count > 0 ? MI_OK : MI_ERR_UNSUPPORTED;
}

static const mi_hardware_port LINUX_HARDWARE = {
    .platform = "linux",
    .read_os = linux_read_os,
    .read_cpu = linux_read_cpu,
    .read_memory = linux_read_memory,
    .read_disks = linux_read_disks,
    .read_temperatures = linux_read_temperatures,
};

const mi_hardware_port *mi_linux_hardware_port(void)
{
    return &LINUX_HARDWARE;
}
