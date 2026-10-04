#ifndef MI_DOMAIN_MODELS_H
#define MI_DOMAIN_MODELS_H

#include <stddef.h>
#include <stdint.h>

#define MI_STR_SMALL 64
#define MI_STR_MEDIUM 256
#define MI_STR_LARGE 512
#define MI_STR_XLARGE 1024

typedef enum {
    MI_OK = 0,
    MI_ERR_UNSUPPORTED = 1,
    MI_ERR_IO = 2,
    MI_ERR_NO_MEMORY = 3,
    MI_ERR_PERMISSION = 4
} mi_status;

typedef struct {
    char name[MI_STR_MEDIUM];
    char version[MI_STR_MEDIUM];
    char kernel[MI_STR_MEDIUM];
    char hostname[MI_STR_MEDIUM];
    char architecture[MI_STR_SMALL];
    uint64_t uptime_seconds;
} mi_os_info;

typedef struct {
    char model[MI_STR_MEDIUM];
    char vendor[MI_STR_SMALL];
    char architecture[MI_STR_SMALL];
    uint32_t physical_cores;
    uint32_t logical_cores;
    double base_frequency_mhz;
    double usage_percent;
} mi_cpu_info;

typedef struct {
    uint64_t total_bytes;
    uint64_t available_bytes;
    uint64_t used_bytes;
    uint64_t swap_total_bytes;
    uint64_t swap_used_bytes;
} mi_memory_info;

typedef enum {
    MI_DISK_UNKNOWN = 0,
    MI_DISK_FIXED,
    MI_DISK_REMOVABLE,
    MI_DISK_NETWORK,
    MI_DISK_OPTICAL,
    MI_DISK_RAM
} mi_disk_kind;

typedef struct {
    char name[MI_STR_MEDIUM];
    char mount_point[MI_STR_LARGE];
    char filesystem[MI_STR_SMALL];
    mi_disk_kind kind;
    uint64_t total_bytes;
    uint64_t free_bytes;
    uint64_t used_bytes;
} mi_disk_info;

typedef struct {
    char label[MI_STR_MEDIUM];
    char source[MI_STR_SMALL];
    double celsius;
    double critical_celsius;
} mi_temperature;

typedef struct {
    char name[MI_STR_MEDIUM];
    char version[MI_STR_SMALL];
    char publisher[MI_STR_MEDIUM];
    char source[MI_STR_SMALL];
    char install_location[MI_STR_LARGE];
    char icon_path[MI_STR_LARGE];
    char uninstall_command[MI_STR_XLARGE];
    char install_date[MI_STR_SMALL];
    uint64_t size_bytes;
} mi_package;

#define MI_DECLARE_LIST(type, list_name) \
    typedef struct {                     \
        type *items;                     \
        size_t count;                    \
        size_t capacity;                 \
    } list_name

typedef struct {
    unsigned char *data;
    size_t length;
} mi_buffer;

MI_DECLARE_LIST(mi_disk_info, mi_disk_list);
MI_DECLARE_LIST(mi_temperature, mi_temperature_list);
MI_DECLARE_LIST(mi_package, mi_package_list);

mi_disk_info *mi_disk_list_push(mi_disk_list *list);
mi_temperature *mi_temperature_list_push(mi_temperature_list *list);
mi_package *mi_package_list_push(mi_package_list *list);

void mi_disk_list_free(mi_disk_list *list);
void mi_temperature_list_free(mi_temperature_list *list);
void mi_package_list_free(mi_package_list *list);

void mi_buffer_free(mi_buffer *buffer);

void mi_copy_str(char *dst, size_t dst_size, const char *src);
void mi_trim(char *s);
const char *mi_disk_kind_name(mi_disk_kind kind);

#endif
