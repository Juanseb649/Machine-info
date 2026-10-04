#ifndef MI_TEXT_UTILS_H
#define MI_TEXT_UTILS_H

#include <stddef.h>

typedef void (*mi_line_handler)(char *line, void *ctx);

int mi_read_file_lines(const char *path, mi_line_handler handler, void *ctx);
int mi_read_first_line(const char *path, char *out, size_t out_size);
int mi_run_command_lines(const char *command, mi_line_handler handler, void *ctx);
int mi_command_exists(const char *name);
int mi_starts_with(const char *s, const char *prefix);
void mi_shell_quote(const char *in, char *out, size_t out_size);
int mi_ends_with(const char *s, const char *suffix);
int mi_split_key_value(char *line, char separator, char **key, char **value);

#endif
