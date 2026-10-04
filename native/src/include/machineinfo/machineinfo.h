#ifndef MACHINEINFO_H
#define MACHINEINFO_H

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#  if defined(MACHINEINFO_BUILDING)
#    define MI_API __declspec(dllexport)
#  else
#    define MI_API __declspec(dllimport)
#  endif
#else
#  define MI_API __attribute__((visibility("default")))
#endif

/*
 * section: "os" | "cpu" | "memory" | "disks" | "temperatures" | "software" | "hardware" | "all"
 * Returns a UTF-8 JSON string owned by the caller; release it with mi_free_string.
 */
MI_API char *mi_collect_json(const char *section);
MI_API void mi_free_string(char *value);
MI_API const char *mi_version(void);

/*
 * icon_path: platform icon reference (Windows: "C:\\path\\app.exe,0" or .ico).
 * Returns a base64-encoded PNG owned by the caller (mi_free_string), or NULL.
 */
MI_API char *mi_app_icon_png_base64(const char *icon_path, int size);

/* Returns 0 on success, otherwise a mi_status code (1 unsupported, 2 io, 4 permission). */
MI_API int mi_launch_uninstaller(const char *command);

#ifdef __cplusplus
}
#endif

#endif
