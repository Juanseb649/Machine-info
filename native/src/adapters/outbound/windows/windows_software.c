#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#include "win_utils.h"

#include <objbase.h>
#include <shellapi.h>
#include <shlobj.h>

#include "../../../ports/software_port.h"
#include "../common/png_writer.h"

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

static void strip_quotes(char *s)
{
    mi_trim(s);
    size_t len = strlen(s);
    if (len >= 2 && s[0] == '"') {
        char *close = strchr(s + 1, '"');
        if (close) {
            size_t inner = (size_t)(close - s - 1);
            memmove(s, s + 1, inner);
            s[inner] = '\0';
        }
    }
}

static void icon_file_part(const char *icon, char *out, size_t out_size)
{
    mi_copy_str(out, out_size, icon);
    strip_quotes(out);
    char *comma = strrchr(out, ',');
    if (comma) {
        char *p = comma + 1;
        while (*p == ' ') p++;
        if (*p == '-') p++;
        int digits = 0;
        while (*p >= '0' && *p <= '9') {
            p++;
            digits++;
        }
        if (digits > 0 && *p == '\0') *comma = '\0';
    }
    mi_trim(out);
}

static void parent_directory(char *path)
{
    char *slash = strrchr(path, '\\');
    if (!slash) slash = strrchr(path, '/');
    if (slash) *slash = '\0';
    else path[0] = '\0';
}

static int contains_ci(const char *haystack, const char *needle)
{
    size_t n = strlen(needle);
    for (const char *h = haystack; *h; h++)
        if (_strnicmp(h, needle, n) == 0) return 1;
    return 0;
}

static void derive_install_location(mi_package *pkg)
{
    strip_quotes(pkg->install_location);
    size_t len = strlen(pkg->install_location);
    while (len > 3 && (pkg->install_location[len - 1] == '\\' || pkg->install_location[len - 1] == '/'))
        pkg->install_location[--len] = '\0';
    if (pkg->install_location[0]) return;
    if (!pkg->icon_path[0]) return;

    char file[MI_STR_LARGE];
    icon_file_part(pkg->icon_path, file, sizeof(file));
    if (!file[0] || contains_ci(file, "\\Windows\\Installer") || contains_ci(file, "%SystemRoot%") ||
        contains_ci(file, "\\Windows\\System32"))
        return;
    parent_directory(file);
    mi_copy_str(pkg->install_location, sizeof(pkg->install_location), file);
}

static void normalize_msi_uninstall(char *command)
{
    if (!contains_ci(command, "msiexec")) return;
    for (char *p = command; *p; p++) {
        if ((p[0] == '/' || p[0] == '-') && (p[1] == 'I' || p[1] == 'i') && (p[2] == '{' || p[2] == ' ')) {
            p[1] = 'X';
            return;
        }
    }
}

static void format_install_date(const char *raw, char *out, size_t out_size)
{
    out[0] = '\0';
    if (strlen(raw) != 8) return;
    for (int i = 0; i < 8; i++)
        if (raw[i] < '0' || raw[i] > '9') return;
    char formatted[11] = {raw[0], raw[1], raw[2], raw[3], '-', raw[4], raw[5], '-', raw[6], raw[7], '\0'};
    mi_copy_str(out, out_size, formatted);
}

static void read_entry(HKEY entry, const uninstall_location *loc, mi_package *pkg)
{
    mi_key_read_string(entry, L"DisplayVersion", pkg->version, sizeof(pkg->version));
    mi_key_read_string(entry, L"Publisher", pkg->publisher, sizeof(pkg->publisher));
    mi_key_read_string(entry, L"InstallLocation", pkg->install_location, sizeof(pkg->install_location));
    mi_key_read_string(entry, L"DisplayIcon", pkg->icon_path, sizeof(pkg->icon_path));
    mi_trim(pkg->icon_path);
    if (!mi_key_read_string(entry, L"UninstallString", pkg->uninstall_command, sizeof(pkg->uninstall_command)))
        mi_key_read_string(entry, L"QuietUninstallString", pkg->uninstall_command, sizeof(pkg->uninstall_command));
    mi_trim(pkg->uninstall_command);
    normalize_msi_uninstall(pkg->uninstall_command);

    char date[MI_STR_SMALL];
    if (mi_key_read_string(entry, L"InstallDate", date, sizeof(date))) {
        mi_trim(date);
        format_install_date(date, pkg->install_date, sizeof(pkg->install_date));
    }
    DWORD size_kb = 0;
    if (mi_key_read_dword(entry, L"EstimatedSize", &size_kb)) pkg->size_bytes = (uint64_t)size_kb * 1024u;

    derive_install_location(pkg);
    mi_copy_str(pkg->source, sizeof(pkg->source), loc->source);
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

        mi_package *pkg = calloc(1, sizeof(mi_package));
        if (pkg && mi_key_read_string(entry, L"DisplayName", pkg->name, sizeof(pkg->name)) && !is_hidden_entry(entry)) {
            read_entry(entry, loc, pkg);
            mi_package *slot = mi_package_list_push(out);
            if (slot) *slot = *pkg;
        }
        free(pkg);
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

static int utf8_to_wide(const char *src, wchar_t *dst, int dst_len)
{
    if (!src || !dst || dst_len <= 0) return 0;
    dst[0] = L'\0';
    return MultiByteToWideChar(CP_UTF8, 0, src, -1, dst, dst_len) > 0;
}

static int parse_icon_location(const char *icon, wchar_t *file, DWORD file_len, int *index)
{
    char raw[MI_STR_XLARGE];
    mi_copy_str(raw, sizeof(raw), icon);
    strip_quotes(raw);
    *index = 0;
    char *comma = strrchr(raw, ',');
    if (comma) {
        char *end = NULL;
        long value = strtol(comma + 1, &end, 10);
        while (end && *end == ' ') end++;
        if (end && end != comma + 1 && *end == '\0') {
            *index = (int)value;
            *comma = '\0';
        }
    }
    mi_trim(raw);
    strip_quotes(raw);
    if (!raw[0]) return 0;

    wchar_t wide[MAX_PATH * 2];
    if (!utf8_to_wide(raw, wide, (int)(sizeof(wide) / sizeof(wide[0])))) return 0;
    DWORD n = ExpandEnvironmentStringsW(wide, file, file_len);
    if (n == 0 || n > file_len) {
        wcsncpy(file, wide, file_len - 1);
        file[file_len - 1] = L'\0';
    }
    return 1;
}

static mi_status icon_to_png(HICON icon, mi_buffer *out)
{
    ICONINFO info;
    if (!GetIconInfo(icon, &info)) return MI_ERR_IO;

    mi_status status = MI_ERR_IO;
    BITMAP bm;
    HDC dc = GetDC(NULL);
    unsigned char *pixels = NULL;
    unsigned char *mask = NULL;

    if (!info.hbmColor || !GetObjectW(info.hbmColor, sizeof(bm), &bm)) goto done;
    int width = bm.bmWidth, height = bm.bmHeight;
    if (width <= 0 || height <= 0 || width > 1024 || height > 1024) goto done;

    BITMAPINFO bi;
    memset(&bi, 0, sizeof(bi));
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = width;
    bi.bmiHeader.biHeight = -height;
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;

    size_t bytes = (size_t)width * (size_t)height * 4;
    pixels = malloc(bytes);
    mask = malloc(bytes);
    if (!pixels || !mask) {
        status = MI_ERR_NO_MEMORY;
        goto done;
    }
    if (!GetDIBits(dc, info.hbmColor, 0, (UINT)height, pixels, &bi, DIB_RGB_COLORS)) goto done;

    int has_alpha = 0;
    for (size_t i = 3; i < bytes; i += 4)
        if (pixels[i]) {
            has_alpha = 1;
            break;
        }
    int has_mask = info.hbmMask && GetDIBits(dc, info.hbmMask, 0, (UINT)height, mask, &bi, DIB_RGB_COLORS);

    for (size_t i = 0; i < bytes; i += 4) {
        unsigned char b = pixels[i], r = pixels[i + 2];
        pixels[i] = r;
        pixels[i + 2] = b;
        if (!has_alpha) pixels[i + 3] = (has_mask && mask[i]) ? 0 : 255;
    }
    status = mi_png_encode_rgba(pixels, width, height, out);

done:
    free(pixels);
    free(mask);
    ReleaseDC(NULL, dc);
    if (info.hbmColor) DeleteObject(info.hbmColor);
    if (info.hbmMask) DeleteObject(info.hbmMask);
    return status;
}

static mi_status windows_extract_icon_png(const char *icon_path, int size, mi_buffer *out)
{
    out->data = NULL;
    out->length = 0;
    if (!icon_path || !icon_path[0]) return MI_ERR_IO;
    if (size <= 0 || size > 256) size = 64;

    wchar_t file[MAX_PATH * 2];
    int index = 0;
    if (!parse_icon_location(icon_path, file, (DWORD)(sizeof(file) / sizeof(file[0])), &index)) return MI_ERR_IO;

    HICON icon = NULL;
    HRESULT hr = SHDefExtractIconW(file, index, 0, &icon, NULL, MAKELONG(size, 16));
    if (hr != S_OK || !icon) {
        icon = NULL;
        SHFILEINFOW sfi;
        memset(&sfi, 0, sizeof(sfi));
        if (SHGetFileInfoW(file, 0, &sfi, sizeof(sfi), SHGFI_ICON | SHGFI_LARGEICON)) icon = sfi.hIcon;
    }
    if (!icon) return MI_ERR_IO;
    mi_status status = icon_to_png(icon, out);
    DestroyIcon(icon);
    return status;
}

static int file_exists(const wchar_t *path)
{
    DWORD attrs = GetFileAttributesW(path);
    return attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY);
}

static int split_command(wchar_t *command, wchar_t *file, size_t file_len, const wchar_t **params)
{
    while (*command == L' ') command++;
    if (*command == L'"') {
        wchar_t *close = wcschr(command + 1, L'"');
        if (!close) return 0;
        size_t n = (size_t)(close - command - 1);
        if (n >= file_len) return 0;
        wcsncpy(file, command + 1, n);
        file[n] = L'\0';
        *params = close + 1;
        while (**params == L' ') (*params)++;
        return 1;
    }

    size_t total = wcslen(command);
    for (size_t i = 0; i <= total; i++) {
        if (command[i] != L' ' && command[i] != L'\0') continue;
        if (i >= file_len) break;
        wcsncpy(file, command, i);
        file[i] = L'\0';
        int exists = file_exists(file);
        if (!exists && i + 5 < file_len) {
            wcscat(file, L".exe");
            exists = file_exists(file);
        }
        if (exists) {
            *params = command + i;
            while (**params == L' ') (*params)++;
            return 1;
        }
    }

    wchar_t *space = wcschr(command, L' ');
    size_t n = space ? (size_t)(space - command) : total;
    if (n >= file_len) return 0;
    wcsncpy(file, command, n);
    file[n] = L'\0';
    *params = space ? space + 1 : L"";
    return 1;
}

static mi_status windows_launch_uninstaller(const char *command)
{
    if (!command || !command[0]) return MI_ERR_UNSUPPORTED;

    wchar_t raw[MI_STR_XLARGE];
    if (!utf8_to_wide(command, raw, (int)(sizeof(raw) / sizeof(raw[0])))) return MI_ERR_IO;
    wchar_t expanded[MI_STR_XLARGE * 2];
    DWORD n = ExpandEnvironmentStringsW(raw, expanded, (DWORD)(sizeof(expanded) / sizeof(expanded[0])));
    if (n == 0 || n > sizeof(expanded) / sizeof(expanded[0])) wcscpy(expanded, raw);

    wchar_t file[MAX_PATH * 2];
    const wchar_t *params = L"";
    if (!split_command(expanded, file, sizeof(file) / sizeof(file[0]), &params)) return MI_ERR_IO;

    HRESULT com = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);

    SHELLEXECUTEINFOW sei;
    memset(&sei, 0, sizeof(sei));
    sei.cbSize = sizeof(sei);
    sei.fMask = SEE_MASK_NOASYNC | SEE_MASK_FLAG_NO_UI;
    sei.lpVerb = L"open";
    sei.lpFile = file;
    sei.lpParameters = params[0] ? params : NULL;
    sei.nShow = SW_SHOWNORMAL;
    BOOL ok = ShellExecuteExW(&sei);
    DWORD error = ok ? ERROR_SUCCESS : GetLastError();

    if (SUCCEEDED(com)) CoUninitialize();
    if (ok) return MI_OK;
    return error == ERROR_CANCELLED || error == ERROR_ACCESS_DENIED ? MI_ERR_PERMISSION : MI_ERR_IO;
}

static const mi_software_port WINDOWS_SOFTWARE = {
    "windows",
    windows_list_installed,
    windows_extract_icon_png,
    windows_launch_uninstaller,
};

const mi_software_port *mi_windows_software_port(void)
{
    return &WINDOWS_SOFTWARE;
}
