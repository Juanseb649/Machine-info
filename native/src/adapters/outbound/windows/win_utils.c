#include "win_utils.h"

#include "../../../domain/models.h"

void mi_wide_to_utf8(const wchar_t *src, char *dst, size_t dst_size)
{
    if (!dst || dst_size == 0) return;
    dst[0] = '\0';
    if (!src) return;
    int written = WideCharToMultiByte(CP_UTF8, 0, src, -1, dst, (int)dst_size, NULL, NULL);
    if (written <= 0) {
        int needed = WideCharToMultiByte(CP_UTF8, 0, src, -1, NULL, 0, NULL, NULL);
        if (needed <= 0) return;
        char *tmp = (char *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)needed);
        if (!tmp) return;
        WideCharToMultiByte(CP_UTF8, 0, src, -1, tmp, needed, NULL, NULL);
        mi_copy_str(dst, dst_size, tmp);
        HeapFree(GetProcessHeap(), 0, tmp);
    }
}

int mi_key_read_string(HKEY key, const wchar_t *name, char *out, size_t out_size)
{
    wchar_t buffer[1024];
    DWORD size = sizeof(buffer) - sizeof(wchar_t);
    DWORD type = 0;
    if (RegQueryValueExW(key, name, NULL, &type, (LPBYTE)buffer, &size) != ERROR_SUCCESS) return 0;
    if (type != REG_SZ && type != REG_EXPAND_SZ) return 0;
    buffer[size / sizeof(wchar_t)] = L'\0';
    mi_wide_to_utf8(buffer, out, out_size);
    return 1;
}

int mi_key_read_dword(HKEY key, const wchar_t *name, DWORD *out)
{
    DWORD size = sizeof(DWORD);
    DWORD type = 0;
    if (RegQueryValueExW(key, name, NULL, &type, (LPBYTE)out, &size) != ERROR_SUCCESS) return 0;
    return type == REG_DWORD;
}

int mi_reg_read_string(HKEY root, const wchar_t *path, const wchar_t *name, REGSAM extra, char *out, size_t out_size)
{
    HKEY key;
    if (RegOpenKeyExW(root, path, 0, KEY_READ | extra, &key) != ERROR_SUCCESS) return 0;
    int ok = mi_key_read_string(key, name, out, out_size);
    RegCloseKey(key);
    return ok;
}

int mi_reg_read_dword(HKEY root, const wchar_t *path, const wchar_t *name, REGSAM extra, DWORD *out)
{
    HKEY key;
    if (RegOpenKeyExW(root, path, 0, KEY_READ | extra, &key) != ERROR_SUCCESS) return 0;
    int ok = mi_key_read_dword(key, name, out);
    RegCloseKey(key);
    return ok;
}
