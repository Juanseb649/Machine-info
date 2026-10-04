#include "models.h"

#include <ctype.h>
#include <stdlib.h>
#include <string.h>

static void *grow(void **items, size_t *count, size_t *capacity, size_t item_size)
{
    if (*count == *capacity) {
        size_t next = *capacity ? *capacity * 2 : 16;
        void *resized = realloc(*items, next * item_size);
        if (!resized) return NULL;
        *items = resized;
        *capacity = next;
    }
    char *slot = (char *)*items + (*count) * item_size;
    memset(slot, 0, item_size);
    (*count)++;
    return slot;
}

mi_disk_info *mi_disk_list_push(mi_disk_list *list)
{
    return grow((void **)&list->items, &list->count, &list->capacity, sizeof(mi_disk_info));
}

mi_temperature *mi_temperature_list_push(mi_temperature_list *list)
{
    return grow((void **)&list->items, &list->count, &list->capacity, sizeof(mi_temperature));
}

mi_package *mi_package_list_push(mi_package_list *list)
{
    return grow((void **)&list->items, &list->count, &list->capacity, sizeof(mi_package));
}

#define MI_LIST_FREE(list) \
    do {                   \
        free((list)->items); \
        (list)->items = NULL; \
        (list)->count = 0;  \
        (list)->capacity = 0; \
    } while (0)

void mi_disk_list_free(mi_disk_list *list) { MI_LIST_FREE(list); }
void mi_temperature_list_free(mi_temperature_list *list) { MI_LIST_FREE(list); }
void mi_package_list_free(mi_package_list *list) { MI_LIST_FREE(list); }

void mi_buffer_free(mi_buffer *buffer)
{
    free(buffer->data);
    buffer->data = NULL;
    buffer->length = 0;
}

void mi_copy_str(char *dst, size_t dst_size, const char *src)
{
    if (!dst || dst_size == 0) return;
    if (!src) {
        dst[0] = '\0';
        return;
    }
    size_t len = strlen(src);
    if (len >= dst_size) len = dst_size - 1;
    memcpy(dst, src, len);
    dst[len] = '\0';
}

void mi_trim(char *s)
{
    if (!s) return;
    char *start = s;
    while (*start && isspace((unsigned char)*start)) start++;
    if (start != s) memmove(s, start, strlen(start) + 1);
    size_t len = strlen(s);
    while (len > 0 && isspace((unsigned char)s[len - 1])) s[--len] = '\0';
}

const char *mi_disk_kind_name(mi_disk_kind kind)
{
    switch (kind) {
    case MI_DISK_FIXED: return "fixed";
    case MI_DISK_REMOVABLE: return "removable";
    case MI_DISK_NETWORK: return "network";
    case MI_DISK_OPTICAL: return "optical";
    case MI_DISK_RAM: return "ram";
    default: return "unknown";
    }
}
