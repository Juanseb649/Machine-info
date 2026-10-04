#include <stdio.h>
#include <string.h>
#include <intrin.h>

#include "win_utils.h"

#include "../../../ports/hardware_port.h"

mi_status mi_windows_read_thermal_zones(mi_temperature_list *out);

static const wchar_t *NT_VERSION_KEY = L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion";
static const wchar_t *CPU_KEY = L"HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0";

typedef LONG(WINAPI *rtl_get_version_fn)(PRTL_OSVERSIONINFOW);

static const char *arch_name(WORD arch)
{
    switch (arch) {
    case PROCESSOR_ARCHITECTURE_AMD64: return "x86_64";
    case PROCESSOR_ARCHITECTURE_ARM64: return "arm64";
    case PROCESSOR_ARCHITECTURE_ARM: return "arm";
    case PROCESSOR_ARCHITECTURE_INTEL: return "x86";
    default: return "unknown";
    }
}

static void replace_windows_10_with_11(char *name, size_t size)
{
    char *found = strstr(name, "Windows 10");
    if (!found) return;
    char rest[MI_STR_MEDIUM];
    mi_copy_str(rest, sizeof(rest), found + strlen("Windows 10"));
    size_t prefix = (size_t)(found - name);
    snprintf(found, size - prefix, "Windows 11%s", rest);
}

static mi_status windows_read_os(mi_os_info *out)
{
    RTL_OSVERSIONINFOW v = {0};
    v.dwOSVersionInfoSize = sizeof(v);
    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    rtl_get_version_fn rtl_get_version = ntdll ? (rtl_get_version_fn)(void *)GetProcAddress(ntdll, "RtlGetVersion") : NULL;
    if (rtl_get_version) rtl_get_version(&v);

    if (!mi_reg_read_string(HKEY_LOCAL_MACHINE, NT_VERSION_KEY, L"ProductName", KEY_WOW64_64KEY, out->name, sizeof(out->name)))
        mi_copy_str(out->name, sizeof(out->name), "Windows");
    if (v.dwBuildNumber >= 22000) replace_windows_10_with_11(out->name, sizeof(out->name));

    char display[MI_STR_SMALL] = "";
    mi_reg_read_string(HKEY_LOCAL_MACHINE, NT_VERSION_KEY, L"DisplayVersion", KEY_WOW64_64KEY, display, sizeof(display));
    DWORD ubr = 0;
    mi_reg_read_dword(HKEY_LOCAL_MACHINE, NT_VERSION_KEY, L"UBR", KEY_WOW64_64KEY, &ubr);

    if (display[0]) snprintf(out->version, sizeof(out->version), "%s", display);
    else snprintf(out->version, sizeof(out->version), "%lu.%lu", v.dwMajorVersion, v.dwMinorVersion);
    snprintf(out->kernel, sizeof(out->kernel), "NT %lu.%lu.%lu.%lu", v.dwMajorVersion, v.dwMinorVersion, v.dwBuildNumber, ubr);

    wchar_t host[MAX_COMPUTERNAME_LENGTH + 64];
    DWORD host_len = (DWORD)(sizeof(host) / sizeof(host[0]));
    if (GetComputerNameExW(ComputerNameDnsHostname, host, &host_len)) mi_wide_to_utf8(host, out->hostname, sizeof(out->hostname));

    SYSTEM_INFO si;
    GetNativeSystemInfo(&si);
    mi_copy_str(out->architecture, sizeof(out->architecture), arch_name(si.wProcessorArchitecture));
    out->uptime_seconds = GetTickCount64() / 1000ULL;
    return MI_OK;
}

static uint32_t count_physical_cores(void)
{
    DWORD length = 0;
    GetLogicalProcessorInformationEx(RelationProcessorCore, NULL, &length);
    if (length == 0) return 0;
    BYTE *buffer = (BYTE *)HeapAlloc(GetProcessHeap(), 0, length);
    if (!buffer) return 0;
    uint32_t cores = 0;
    if (GetLogicalProcessorInformationEx(RelationProcessorCore, (PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX)buffer, &length)) {
        for (DWORD offset = 0; offset < length;) {
            PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX item = (PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX)(buffer + offset);
            if (item->Relationship == RelationProcessorCore) cores++;
            offset += item->Size;
        }
    }
    HeapFree(GetProcessHeap(), 0, buffer);
    return cores;
}

static uint64_t filetime_u64(FILETIME ft)
{
    return ((uint64_t)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
}

static double sample_cpu_usage(void)
{
    FILETIME idle_a, kernel_a, user_a, idle_b, kernel_b, user_b;
    if (!GetSystemTimes(&idle_a, &kernel_a, &user_a)) return 0;
    Sleep(250);
    if (!GetSystemTimes(&idle_b, &kernel_b, &user_b)) return 0;
    uint64_t idle = filetime_u64(idle_b) - filetime_u64(idle_a);
    uint64_t total = (filetime_u64(kernel_b) - filetime_u64(kernel_a)) + (filetime_u64(user_b) - filetime_u64(user_a));
    if (total == 0) return 0;
    return 100.0 * (double)(total - idle) / (double)total;
}

static void cpuid_brand(char *model, size_t model_size, char *vendor, size_t vendor_size)
{
#if defined(_M_X64) || defined(_M_IX86) || defined(__x86_64__) || defined(__i386__)
    int regs[4];
    char text[64] = {0};
    __cpuid(regs, 0);
    memcpy(text, &regs[1], 4);
    memcpy(text + 4, &regs[3], 4);
    memcpy(text + 8, &regs[2], 4);
    if (vendor[0] == '\0') mi_copy_str(vendor, vendor_size, text);

    __cpuid(regs, (int)0x80000000);
    if ((unsigned)regs[0] < 0x80000004u || model[0] != '\0') return;
    memset(text, 0, sizeof(text));
    for (int i = 0; i < 3; i++) {
        __cpuid(regs, (int)(0x80000002u + (unsigned)i));
        memcpy(text + i * 16, regs, 16);
    }
    mi_copy_str(model, model_size, text);
#else
    (void)model; (void)model_size; (void)vendor; (void)vendor_size;
#endif
}

static mi_status windows_read_cpu(mi_cpu_info *out)
{
    mi_reg_read_string(HKEY_LOCAL_MACHINE, CPU_KEY, L"ProcessorNameString", 0, out->model, sizeof(out->model));
    mi_reg_read_string(HKEY_LOCAL_MACHINE, CPU_KEY, L"VendorIdentifier", 0, out->vendor, sizeof(out->vendor));
    cpuid_brand(out->model, sizeof(out->model), out->vendor, sizeof(out->vendor));

    DWORD mhz = 0;
    if (mi_reg_read_dword(HKEY_LOCAL_MACHINE, CPU_KEY, L"~MHz", 0, &mhz)) out->base_frequency_mhz = (double)mhz;

    SYSTEM_INFO si;
    GetNativeSystemInfo(&si);
    mi_copy_str(out->architecture, sizeof(out->architecture), arch_name(si.wProcessorArchitecture));

    DWORD logical = GetActiveProcessorCount(ALL_PROCESSOR_GROUPS);
    out->logical_cores = logical ? logical : si.dwNumberOfProcessors;
    out->physical_cores = count_physical_cores();
    out->usage_percent = sample_cpu_usage();
    return MI_OK;
}

static mi_status windows_read_memory(mi_memory_info *out)
{
    MEMORYSTATUSEX m;
    m.dwLength = sizeof(m);
    if (!GlobalMemoryStatusEx(&m)) return MI_ERR_IO;
    out->total_bytes = m.ullTotalPhys;
    out->available_bytes = m.ullAvailPhys;
    out->used_bytes = m.ullTotalPhys - m.ullAvailPhys;

    if (m.ullTotalPageFile > m.ullTotalPhys) {
        out->swap_total_bytes = m.ullTotalPageFile - m.ullTotalPhys;
        uint64_t commit_used = m.ullTotalPageFile - m.ullAvailPageFile;
        out->swap_used_bytes = commit_used > out->used_bytes ? commit_used - out->used_bytes : 0;
    }
    return MI_OK;
}

static mi_disk_kind drive_kind(UINT type)
{
    switch (type) {
    case DRIVE_FIXED: return MI_DISK_FIXED;
    case DRIVE_REMOVABLE: return MI_DISK_REMOVABLE;
    case DRIVE_REMOTE: return MI_DISK_NETWORK;
    case DRIVE_CDROM: return MI_DISK_OPTICAL;
    case DRIVE_RAMDISK: return MI_DISK_RAM;
    default: return MI_DISK_UNKNOWN;
    }
}

static mi_status windows_read_disks(mi_disk_list *out)
{
    wchar_t drives[512];
    DWORD len = GetLogicalDriveStringsW((DWORD)(sizeof(drives) / sizeof(drives[0])), drives);
    if (len == 0 || len > sizeof(drives) / sizeof(drives[0])) return MI_ERR_IO;

    UINT previous_mode = SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOOPENFILEERRORBOX);
    for (wchar_t *root = drives; *root; root += wcslen(root) + 1) {
        ULARGE_INTEGER available, total, total_free;
        if (!GetDiskFreeSpaceExW(root, &available, &total, &total_free)) continue;

        mi_disk_info *d = mi_disk_list_push(out);
        if (!d) break;

        wchar_t label[MAX_PATH + 1] = L"", fs[MAX_PATH + 1] = L"";
        GetVolumeInformationW(root, label, MAX_PATH + 1, NULL, NULL, NULL, fs, MAX_PATH + 1);

        mi_wide_to_utf8(root, d->mount_point, sizeof(d->mount_point));
        mi_wide_to_utf8(label[0] ? label : root, d->name, sizeof(d->name));
        mi_wide_to_utf8(fs, d->filesystem, sizeof(d->filesystem));
        d->kind = drive_kind(GetDriveTypeW(root));
        d->total_bytes = total.QuadPart;
        d->free_bytes = available.QuadPart;
        d->used_bytes = total.QuadPart - total_free.QuadPart;
    }
    SetErrorMode(previous_mode);
    return MI_OK;
}

static const mi_hardware_port WINDOWS_HARDWARE = {
    "windows",
    windows_read_os,
    windows_read_cpu,
    windows_read_memory,
    windows_read_disks,
    mi_windows_read_thermal_zones,
};

const mi_hardware_port *mi_windows_hardware_port(void)
{
    return &WINDOWS_HARDWARE;
}
