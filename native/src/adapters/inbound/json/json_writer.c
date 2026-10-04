#include "json_writer.h"

#include <inttypes.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void mi_json_init(mi_json *j)
{
    memset(j, 0, sizeof(*j));
}

void mi_json_dispose(mi_json *j)
{
    free(j->data);
    mi_json_init(j);
}

char *mi_json_take(mi_json *j)
{
    if (j->failed) {
        mi_json_dispose(j);
        return NULL;
    }
    char *out = j->data;
    j->data = NULL;
    mi_json_dispose(j);
    return out;
}

static void append(mi_json *j, const char *s, size_t n)
{
    if (j->failed) return;
    if (j->length + n + 1 > j->capacity) {
        size_t next = j->capacity ? j->capacity : 1024;
        while (next < j->length + n + 1) next *= 2;
        char *resized = realloc(j->data, next);
        if (!resized) {
            j->failed = 1;
            return;
        }
        j->data = resized;
        j->capacity = next;
    }
    memcpy(j->data + j->length, s, n);
    j->length += n;
    j->data[j->length] = '\0';
}

static void append_str(mi_json *j, const char *s)
{
    append(j, s, strlen(s));
}

static void separator(mi_json *j)
{
    if (j->needs_comma) append(j, ",", 1);
    j->needs_comma = 1;
}

void mi_json_begin_object(mi_json *j)
{
    separator(j);
    append(j, "{", 1);
    j->needs_comma = 0;
}

void mi_json_end_object(mi_json *j)
{
    append(j, "}", 1);
    j->needs_comma = 1;
}

void mi_json_begin_array(mi_json *j)
{
    separator(j);
    append(j, "[", 1);
    j->needs_comma = 0;
}

void mi_json_end_array(mi_json *j)
{
    append(j, "]", 1);
    j->needs_comma = 1;
}

static void write_escaped(mi_json *j, const char *value)
{
    append(j, "\"", 1);
    for (const unsigned char *p = (const unsigned char *)value; p && *p; p++) {
        char buf[8];
        switch (*p) {
        case '"': append(j, "\\\"", 2); break;
        case '\\': append(j, "\\\\", 2); break;
        case '\n': append(j, "\\n", 2); break;
        case '\r': append(j, "\\r", 2); break;
        case '\t': append(j, "\\t", 2); break;
        default:
            if (*p < 0x20) {
                snprintf(buf, sizeof(buf), "\\u%04x", *p);
                append_str(j, buf);
            } else {
                append(j, (const char *)p, 1);
            }
        }
    }
    append(j, "\"", 1);
}

void mi_json_key(mi_json *j, const char *key)
{
    separator(j);
    write_escaped(j, key);
    append(j, ":", 1);
    j->needs_comma = 0;
}

void mi_json_string(mi_json *j, const char *value)
{
    separator(j);
    write_escaped(j, value ? value : "");
}

void mi_json_u64(mi_json *j, uint64_t value)
{
    char buf[32];
    separator(j);
    snprintf(buf, sizeof(buf), "%" PRIu64, value);
    append_str(j, buf);
}

void mi_json_double(mi_json *j, double value)
{
    char buf[48];
    separator(j);
    if (isnan(value) || isinf(value)) {
        append_str(j, "null");
        return;
    }
    int negative = value < 0;
    double magnitude = negative ? -value : value;
    if (magnitude > 9.0e15) magnitude = 9.0e15;
    uint64_t hundredths = (uint64_t)(magnitude * 100.0 + 0.5);
    snprintf(buf, sizeof(buf), "%s%" PRIu64 ".%02u", negative && hundredths ? "-" : "",
             hundredths / 100, (unsigned)(hundredths % 100));
    append_str(j, buf);
}

void mi_json_bool(mi_json *j, int value)
{
    separator(j);
    append_str(j, value ? "true" : "false");
}

void mi_json_null(mi_json *j)
{
    separator(j);
    append_str(j, "null");
}

void mi_json_kv_string(mi_json *j, const char *key, const char *value)
{
    mi_json_key(j, key);
    mi_json_string(j, value);
}

void mi_json_kv_u64(mi_json *j, const char *key, uint64_t value)
{
    mi_json_key(j, key);
    mi_json_u64(j, value);
}

void mi_json_kv_double(mi_json *j, const char *key, double value)
{
    mi_json_key(j, key);
    mi_json_double(j, value);
}
