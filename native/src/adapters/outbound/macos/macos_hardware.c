#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/param.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <sys/utsname.h>
#include <time.h>
#include <unistd.h>

#include <CoreFoundation/CoreFoundation.h>
#include <DiskArbitration/DiskArbitration.h>
#include <mach/mach.h>
#include <mach/mach_host.h>

#include "../../../ports/hardware_port.h"

mi_status mi_macos_read_smc_temperatures(mi_temperature_list *out);

static int sysctl_string(const char *name, char *out, size_t out_size)
{
    size_t size = out_size;
    if (sysctlbyname(name, out, &size, NULL, 0) != 0) return 0;
    out[out_size - 1] = '\0';
    return 1;
}

static uint64_t sysctl_u64(const char *name)
{
    uint64_t value64 = 0;
    size_t size = sizeof(value64);
    if (sysctlbyname(name, &value64, &size, NULL, 0) != 0) return 0;
    if (size == sizeof(uint32_t)) return (uint64_t)(*(uint32_t *)&value64);
    return value64;
}

static mi_status macos_read_os(mi_os_info *out)
{
    char version[MI_STR_SMALL] = "";
    sysctl_string("kern.osproductversion", version, sizeof(version));
    mi_copy_str(out->version, sizeof(out->version), version);
    snprintf(out->name, sizeof(out->name), "macOS %s", version);

    struct utsname u;
    if (uname(&u) == 0) {
        snprintf(out->kernel, sizeof(out->kernel), "Darwin %s", u.release);
        mi_copy_str(out->architecture, sizeof(out->architecture), u.machine);
    }
    gethostname(out->hostname, sizeof(out->hostname) - 1);

    struct timeval boot;
    size_t size = sizeof(boot);
    if (sysctlbyname("kern.boottime", &boot, &size, NULL, 0) == 0) {
        time_t now = time(NULL);
        if (now > boot.tv_sec) out->uptime_seconds = (uint64_t)(now - boot.tv_sec);
    }
    return MI_OK;
}

static int cpu_ticks(uint64_t *busy, uint64_t *total)
{
    host_cpu_load_info_data_t info;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&info, &count) != KERN_SUCCESS) return 0;
    uint64_t user = info.cpu_ticks[CPU_STATE_USER];
    uint64_t sys = info.cpu_ticks[CPU_STATE_SYSTEM];
    uint64_t nice = info.cpu_ticks[CPU_STATE_NICE];
    uint64_t idle = info.cpu_ticks[CPU_STATE_IDLE];
    *busy = user + sys + nice;
    *total = user + sys + nice + idle;
    return 1;
}

static double sample_cpu_usage(void)
{
    uint64_t busy_a, total_a, busy_b, total_b;
    if (!cpu_ticks(&busy_a, &total_a)) return 0;
    usleep(250 * 1000);
    if (!cpu_ticks(&busy_b, &total_b)) return 0;
    uint64_t total = total_b - total_a;
    if (total == 0) return 0;
    return 100.0 * (double)(busy_b - busy_a) / (double)total;
}

static mi_status macos_read_cpu(mi_cpu_info *out)
{
    sysctl_string("machdep.cpu.brand_string", out->model, sizeof(out->model));
    if (!sysctl_string("machdep.cpu.vendor", out->vendor, sizeof(out->vendor)))
        mi_copy_str(out->vendor, sizeof(out->vendor), "Apple");

    struct utsname u;
    if (uname(&u) == 0) mi_copy_str(out->architecture, sizeof(out->architecture), u.machine);

    out->physical_cores = (uint32_t)sysctl_u64("hw.physicalcpu");
    out->logical_cores = (uint32_t)sysctl_u64("hw.logicalcpu");
    out->base_frequency_mhz = (double)sysctl_u64("hw.cpufrequency") / 1e6;
    out->usage_percent = sample_cpu_usage();
    return MI_OK;
}

static mi_status macos_read_memory(mi_memory_info *out)
{
    out->total_bytes = sysctl_u64("hw.memsize");

    vm_size_t page_size = 0;
    host_page_size(mach_host_self(), &page_size);
    vm_statistics64_data_t vm;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    if (host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&vm, &count) != KERN_SUCCESS)
        return MI_ERR_IO;

    uint64_t available = ((uint64_t)vm.free_count + vm.inactive_count + vm.purgeable_count + vm.speculative_count) * page_size;
    out->available_bytes = available;
    out->used_bytes = out->total_bytes > available ? out->total_bytes - available : 0;

    struct xsw_usage swap;
    size_t size = sizeof(swap);
    if (sysctlbyname("vm.swapusage", &swap, &size, NULL, 0) == 0) {
        out->swap_total_bytes = swap.xsu_total;
        out->swap_used_bytes = swap.xsu_used;
    }
    return MI_OK;
}

static mi_disk_kind disk_kind(DASessionRef session, const struct statfs *fs)
{
    if (!(fs->f_flags & MNT_LOCAL)) return MI_DISK_NETWORK;
    if (!session) return MI_DISK_FIXED;

    mi_disk_kind kind = MI_DISK_FIXED;
    const char *bsd = fs->f_mntfromname;
    if (strncmp(bsd, "/dev/", 5) == 0) bsd += 5;
    DADiskRef disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsd);
    if (!disk) return kind;
    CFDictionaryRef desc = DADiskCopyDescription(disk);
    if (desc) {
        CFBooleanRef internal = CFDictionaryGetValue(desc, kDADiskDescriptionDeviceInternalKey);
        CFBooleanRef removable = CFDictionaryGetValue(desc, kDADiskDescriptionMediaRemovableKey);
        CFBooleanRef ejectable = CFDictionaryGetValue(desc, kDADiskDescriptionMediaEjectableKey);
        if ((removable && CFBooleanGetValue(removable)) || (ejectable && CFBooleanGetValue(ejectable)) ||
            (internal && !CFBooleanGetValue(internal)))
            kind = MI_DISK_REMOVABLE;
        CFRelease(desc);
    }
    CFRelease(disk);
    return kind;
}

static int is_hidden_mount(const struct statfs *fs)
{
    static const char *ignored_types[] = {"devfs", "autofs", "nullfs", NULL};
    for (int i = 0; ignored_types[i]; i++)
        if (strcmp(fs->f_fstypename, ignored_types[i]) == 0) return 1;
    if (strncmp(fs->f_mntonname, "/System/Volumes/", 16) == 0) return 1;
    if (strncmp(fs->f_mntonname, "/private/var/vm", 15) == 0) return 1;
    return 0;
}

static void volume_name(const struct statfs *fs, char *out, size_t out_size)
{
    if (strcmp(fs->f_mntonname, "/") == 0) {
        mi_copy_str(out, out_size, "Macintosh HD");
        return;
    }
    const char *base = strrchr(fs->f_mntonname, '/');
    mi_copy_str(out, out_size, base && base[1] ? base + 1 : fs->f_mntfromname);
}

static mi_status macos_read_disks(mi_disk_list *out)
{
    struct statfs *mounts = NULL;
    int count = getmntinfo(&mounts, MNT_NOWAIT);
    if (count <= 0) return MI_ERR_IO;

    DASessionRef session = DASessionCreate(kCFAllocatorDefault);
    for (int i = 0; i < count; i++) {
        const struct statfs *fs = &mounts[i];
        if (is_hidden_mount(fs)) continue;

        mi_disk_info *d = mi_disk_list_push(out);
        if (!d) break;
        volume_name(fs, d->name, sizeof(d->name));
        mi_copy_str(d->mount_point, sizeof(d->mount_point), fs->f_mntonname);
        mi_copy_str(d->filesystem, sizeof(d->filesystem), fs->f_fstypename);
        d->kind = disk_kind(session, fs);
        d->total_bytes = (uint64_t)fs->f_blocks * fs->f_bsize;
        d->free_bytes = (uint64_t)fs->f_bavail * fs->f_bsize;
        d->used_bytes = (uint64_t)(fs->f_blocks - fs->f_bfree) * fs->f_bsize;
    }
    if (session) CFRelease(session);
    return MI_OK;
}

static const mi_hardware_port MACOS_HARDWARE = {
    .platform = "macos",
    .read_os = macos_read_os,
    .read_cpu = macos_read_cpu,
    .read_memory = macos_read_memory,
    .read_disks = macos_read_disks,
    .read_temperatures = mi_macos_read_smc_temperatures,
};

const mi_hardware_port *mi_macos_hardware_port(void)
{
    return &MACOS_HARDWARE;
}
