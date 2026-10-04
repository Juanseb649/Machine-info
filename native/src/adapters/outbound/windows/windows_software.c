#include <string.h>

#include "win_utils.h"

#include "../../../ports/software_port.h"

static const wchar_t *UNINSTALL_KEY = L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall";

typedef struct {
    HKEY root;
    REGSAM view;
    const char *source;
} uninstall_location;

static int is_hidden_entry(HKEY entry)
{
    DWORD system_component = 0;
    if (mi_key_read_dword(entry, L"SystemComponent", &system_component) && system_component == 1) return 1;

    char buffer[MI_STR_SMALL];
    if (mi_key_read_string(entry, L"ParentKeyName", buffer, sizeof(buffer))) return 1;
    if (mi_key_read_string(entry, L"ReleaseType", buffer, sizeof(buffer)) &&
        (strstr(buffer, "Update") || strstr(buffer, "Hotfix")))
        return 1;
    return 0;
}

static int read_location(const uninstall_location *loc, mi_package_list *out)
{
    HKEY uninstall;
    if (RegOpenKeyExW(loc->root, UNINSTALL_KEY, 0, KEY_READ | loc->view, &uninstall) != ERROR_SUCCESS) return 0;

    wchar_t sub_name[256];
    for (DWORD index = 0;; index++) {
        DWORD sub_len = (DWORD)(sizeof(sub_name) / sizeof(sub_name[0]));
        LONG rc = RegEnumKeyExW(uninstall, index, sub_name, &sub_len, NULL, NULL, NULL, NULL);
        if (rc == ERROR_NO_MORE_ITEMS) break;
        if (rc != ERROR_SUCCESS) continue;

        HKEY entry;
        if (RegOpenKeyExW(uninstall, sub_name, 0, KEY_READ | loc->view, &entry) != ERROR_SUCCESS) continue;

        mi_package pkg = {0};
        if (mi_key_read_string(entry, L"DisplayName", pkg.name, sizeof(pkg.name)) && !is_hidden_entry(entry)) {
            mi_key_read_string(entry, L"DisplayVersion", pkg.version, sizeof(pkg.version));
            mi_key_read_string(entry, L"Publisher", pkg.publisher, sizeof(pkg.publisher));
            mi_copy_str(pkg.source, sizeof(pkg.source), loc->source);
            mi_package *slot = mi_package_list_push(out);
            if (slot) *slot = pkg;
        }
        RegCloseKey(entry);
    }
    RegCloseKey(uninstall);
    return 1;
}

static mi_status windows_list_installed(mi_package_list *out)
{
    const uninstall_location locations[] = {
        {HKEY_LOCAL_MACHINE, KEY_WOW64_64KEY, "system-x64"},
        {HKEY_LOCAL_MACHINE, KEY_WOW64_32KEY, "system-x86"},
        {HKEY_CURRENT_USER, 0, "user"},
    };
    int sources = 0;
    for (size_t i = 0; i < sizeof(locations) / sizeof(locations[0]); i++) sources += read_location(&locations[i], out);
    return sources > 0 ? MI_OK : MI_ERR_UNSUPPORTED;
}

static const mi_software_port WINDOWS_SOFTWARE = {
    "windows",
    windows_list_installed,
};

const mi_software_port *mi_windows_software_port(void)
{
    return &WINDOWS_SOFTWARE;
}
