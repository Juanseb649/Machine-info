#ifndef MI_WIN_UTILS_H
#define MI_WIN_UTILS_H

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#include <stddef.h>

void mi_wide_to_utf8(const wchar_t *src, char *dst, size_t dst_size);
int mi_reg_read_string(HKEY root, const wchar_t *path, const wchar_t *name, REGSAM extra, char *out, size_t out_size);
int mi_reg_read_dword(HKEY root, const wchar_t *path, const wchar_t *name, REGSAM extra, DWORD *out);
int mi_key_read_string(HKEY key, const wchar_t *name, char *out, size_t out_size);
int mi_key_read_dword(HKEY key, const wchar_t *name, DWORD *out);

#endif
