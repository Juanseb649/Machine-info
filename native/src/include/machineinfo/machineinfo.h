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

#ifdef __cplusplus
}
#endif

#endif
