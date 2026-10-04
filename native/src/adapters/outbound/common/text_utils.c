#include "text_utils.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../../../domain/models.h"

#if defined(_WIN32)
#define mi_popen _popen
#define mi_pclose _pclose
#define MI_NULL_DEVICE "NUL"
#else
#include <unistd.h>
#define mi_popen popen
#define mi_pclose pclose
#define MI_NULL_DEVICE "/dev/null"
#endif

static void strip_newline(char *line)
{
    size_t len = strlen(line);
    while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r')) line[--len] = '\0';
}

static int feed_lines(FILE *f, mi_line_handler handler, void *ctx)
{
    char buffer[4096];
    int lines = 0;
    while (fgets(buffer, sizeof(buffer), f)) {
        strip_newline(buffer);
        handler(buffer, ctx);
        lines++;
    }
    return lines;
}

int mi_read_file_lines(const char *path, mi_line_handler handler, void *ctx)
{
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    int lines = feed_lines(f, handler, ctx);
    fclose(f);
    return lines;
}

int mi_read_first_line(const char *path, char *out, size_t out_size)
{
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    char buffer[1024];
    int ok = fgets(buffer, sizeof(buffer), f) != NULL;
    fclose(f);
    if (!ok) return -1;
    strip_newline(buffer);
    mi_copy_str(out, out_size, buffer);
    return 0;
}

int mi_run_command_lines(const char *command, mi_line_handler handler, void *ctx)
{
    char full[1024];
    snprintf(full, sizeof(full), "%s 2>" MI_NULL_DEVICE, command);
    FILE *p = mi_popen(full, "r");
    if (!p) return -1;
    int lines = feed_lines(p, handler, ctx);
    int code = mi_pclose(p);
    return code == 0 ? lines : -1;
}

int mi_command_exists(const char *name)
{
#if defined(_WIN32)
    (void)name;
    return 0;
#else
    const char *path = getenv("PATH");
    if (!path) path = "/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin";
    char *copy = strdup(path);
    if (!copy) return 0;
    int found = 0;
    char *save = NULL;
    for (char *dir = strtok_r(copy, ":", &save); dir && !found; dir = strtok_r(NULL, ":", &save)) {
        char candidate[1024];
        snprintf(candidate, sizeof(candidate), "%s/%s", dir, name);
        found = access(candidate, X_OK) == 0;
    }
    free(copy);
    return found;
#endif
}

int mi_starts_with(const char *s, const char *prefix)
{
    return strncmp(s, prefix, strlen(prefix)) == 0;
}

int mi_split_key_value(char *line, char separator, char **key, char **value)
{
    char *sep = strchr(line, separator);
    if (!sep) return 0;
    *sep = '\0';
    *key = line;
    *value = sep + 1;
    mi_trim(*key);
    mi_trim(*value);
    return 1;
}

void mi_shell_quote(const char *in, char *out, size_t out_size)
{
    if (!out || out_size < 3) return;
    size_t w = 0;
    out[w++] = '\'';
    for (const char *c = in ? in : ""; *c; c++) {
        if (*c == '\'') {
            if (w + 5 >= out_size) break;
            memcpy(out + w, "'\\''", 4);
            w += 4;
        } else {
            if (w + 2 >= out_size) break;
            out[w++] = *c;
        }
    }
    out[w++] = '\'';
    out[w] = '\0';
}

int mi_ends_with(const char *s, const char *suffix)
{
    size_t ls = strlen(s), lf = strlen(suffix);
    return ls >= lf && strcmp(s + ls - lf, suffix) == 0;
}
