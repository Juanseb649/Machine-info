#ifndef MI_JSON_WRITER_H
#define MI_JSON_WRITER_H

#include <stddef.h>
#include <stdint.h>

typedef struct {
    char *data;
    size_t length;
    size_t capacity;
    int needs_comma;
    int failed;
} mi_json;

void mi_json_init(mi_json *j);
char *mi_json_take(mi_json *j);
void mi_json_dispose(mi_json *j);

void mi_json_begin_object(mi_json *j);
void mi_json_end_object(mi_json *j);
void mi_json_begin_array(mi_json *j);
void mi_json_end_array(mi_json *j);

void mi_json_key(mi_json *j, const char *key);
void mi_json_string(mi_json *j, const char *value);
void mi_json_u64(mi_json *j, uint64_t value);
void mi_json_double(mi_json *j, double value);
void mi_json_bool(mi_json *j, int value);
void mi_json_null(mi_json *j);

void mi_json_kv_string(mi_json *j, const char *key, const char *value);
void mi_json_kv_u64(mi_json *j, const char *key, uint64_t value);
void mi_json_kv_double(mi_json *j, const char *key, double value);

#endif
