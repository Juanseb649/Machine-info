#define _GNU_SOURCE
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <unistd.h>

#include "../../../ports/software_port.h"
#include "../common/text_utils.h"

typedef struct {
    char path[MI_STR_LARGE];
    char id[MI_STR_MEDIUM];
    char icon[MI_STR_MEDIUM];
} desktop_entry;

typedef struct {
    desktop_entry *items;
    size_t count;
    size_t capacity;
} desktop_index;

static int path_exists(const char *path)
{
    struct stat st;
    return stat(path, &st) == 0;
}

static int is_directory(const char *path)
{
    struct stat st;
    return stat(path, &st) == 0 && S_ISDIR(st.st_mode);
}

typedef struct {
    desktop_entry *entry;
    int in_main;
    int hidden;
} desktop_parse_ctx;

static void on_desktop_line(char *line, void *ctx)
{
    desktop_parse_ctx *c = ctx;
    if (line[0] == '[') {
        c->in_main = strcmp(line, "[Desktop Entry]") == 0;
        return;
    }
    if (!c->in_main) return;
    char *key, *value;
    if (!mi_split_key_value(line, '=', &key, &value)) return;
    if (strcmp(key, "Icon") == 0) mi_copy_str(c->entry->icon, sizeof(c->entry->icon), value);
    else if (strcmp(key, "NoDisplay") == 0 && strcmp(value, "true") == 0) c->hidden = 1;
}

static void index_directory(desktop_index *index, const char *dir)
{
    DIR *d = opendir(dir);
    if (!d) return;
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        if (!mi_ends_with(e->d_name, ".desktop")) continue;
        if (index->count == index->capacity) {
            size_t next = index->capacity ? index->capacity * 2 : 64;
            desktop_entry *grown = realloc(index->items, next * sizeof(desktop_entry));
            if (!grown) break;
            index->items = grown;
            index->capacity = next;
        }
        desktop_entry *entry = &index->items[index->count];
        memset(entry, 0, sizeof(*entry));
        snprintf(entry->path, sizeof(entry->path), "%s/%s", dir, e->d_name);
        mi_copy_str(entry->id, sizeof(entry->id), e->d_name);
        entry->id[strlen(entry->id) - strlen(".desktop")] = '\0';
        desktop_parse_ctx ctx = {.entry = entry};
        if (mi_read_file_lines(entry->path, on_desktop_line, &ctx) < 0 || ctx.hidden || !entry->icon[0]) continue;
        index->count++;
    }
    closedir(d);
}

static void build_desktop_index(desktop_index *index)
{
    memset(index, 0, sizeof(*index));
    index_directory(index, "/usr/share/applications");
    index_directory(index, "/usr/local/share/applications");
    index_directory(index, "/var/lib/snapd/desktop/applications");
    index_directory(index, "/var/lib/flatpak/exports/share/applications");
    const char *home = getenv("HOME");
    if (home) {
        char dir[MI_STR_LARGE];
        snprintf(dir, sizeof(dir), "%s/.local/share/applications", home);
        index_directory(index, dir);
        snprintf(dir, sizeof(dir), "%s/.local/share/flatpak/exports/share/applications", home);
        index_directory(index, dir);
    }
}

static const desktop_entry *find_by_path(const desktop_index *index, const char *path)
{
    for (size_t i = 0; i < index->count; i++)
        if (strcmp(index->items[i].path, path) == 0) return &index->items[i];
    return NULL;
}

static const desktop_entry *find_by_id(const desktop_index *index, const char *id)
{
    for (size_t i = 0; i < index->count; i++)
        if (strcasecmp(index->items[i].id, id) == 0) return &index->items[i];
    size_t len = strlen(id);
    for (size_t i = 0; i < index->count; i++) {
        const char *entry_id = index->items[i].id;
        const char *dot = strrchr(entry_id, '.');
        if (dot && strcasecmp(dot + 1, id) == 0) return &index->items[i];
        if (strncasecmp(entry_id, id, len) == 0 && entry_id[len] == '_') return &index->items[i];
    }
    return NULL;
}

static int resolve_icon(const char *name, char *out, size_t out_size)
{
    out[0] = '\0';
    if (!name || !name[0]) return 0;
    if (name[0] == '/') {
        if (!mi_ends_with(name, ".png") || !path_exists(name)) return 0;
        mi_copy_str(out, out_size, name);
        return 1;
    }

    static const char *sizes[] = {"256x256", "128x128", "96x96", "64x64", "48x48", "512x512", "32x32"};
    char roots[4][MI_STR_LARGE];
    int root_count = 0;
    mi_copy_str(roots[root_count++], MI_STR_LARGE, "/usr/share/icons/hicolor");
    mi_copy_str(roots[root_count++], MI_STR_LARGE, "/var/lib/flatpak/exports/share/icons/hicolor");
    const char *home = getenv("HOME");
    if (home) {
        snprintf(roots[root_count++], MI_STR_LARGE, "%s/.local/share/icons/hicolor", home);
        snprintf(roots[root_count++], MI_STR_LARGE, "%s/.local/share/flatpak/exports/share/icons/hicolor", home);
    }

    char candidate[MI_STR_XLARGE];
    for (int r = 0; r < root_count; r++) {
        for (size_t s = 0; s < sizeof(sizes) / sizeof(sizes[0]); s++) {
            snprintf(candidate, sizeof(candidate), "%s/%s/apps/%s.png", roots[r], sizes[s], name);
            if (path_exists(candidate)) {
                mi_copy_str(out, out_size, candidate);
                return 1;
            }
        }
    }
    snprintf(candidate, sizeof(candidate), "/usr/share/pixmaps/%s.png", name);
    if (path_exists(candidate)) {
        mi_copy_str(out, out_size, candidate);
        return 1;
    }
    return 0;
}

static void apply_desktop_entry(mi_package *pkg, const desktop_entry *entry)
{
    if (!entry || pkg->icon_path[0]) return;
    resolve_icon(entry->icon, pkg->icon_path, sizeof(pkg->icon_path));
}

static void set_uninstall(mi_package *pkg, const char *prefix, const char *target)
{
    char quoted[MI_STR_LARGE];
    mi_shell_quote(target, quoted, sizeof(quoted));
    snprintf(pkg->uninstall_command, sizeof(pkg->uninstall_command), "%s %s", prefix, quoted);
}

typedef struct {
    const desktop_index *index;
    mi_package *pkg;
    const char *root;
    char first_binary[MI_STR_LARGE];
} file_list_ctx;

static void on_file_list_line(char *line, void *ctx)
{
    file_list_ctx *c = ctx;
    char path[MI_STR_LARGE];
    if (line[0] == '/') mi_copy_str(path, sizeof(path), line);
    else if (line[0] && line[0] != '%') snprintf(path, sizeof(path), "/%s", line);
    else return;

    if (!c->pkg->icon_path[0] && mi_ends_with(path, ".desktop") && strstr(path, "/applications/"))
        apply_desktop_entry(c->pkg, find_by_path(c->index, path));

    if (!c->pkg->install_location[0] && mi_starts_with(path, "/opt/")) {
        char *slash = strchr(path + 5, '/');
        if (slash) *slash = '\0';
        if (strlen(path) > 5) mi_copy_str(c->pkg->install_location, sizeof(c->pkg->install_location), path);
        return;
    }
    if (!c->first_binary[0] && (mi_starts_with(path, "/usr/bin/") || mi_starts_with(path, "/usr/games/")) &&
        !mi_ends_with(path, "/"))
        mi_copy_str(c->first_binary, sizeof(c->first_binary), path);
}

static void enrich_from_file_list(mi_package *pkg, const desktop_index *index, const char *list_path)
{
    file_list_ctx ctx = {.index = index, .pkg = pkg};
    mi_read_file_lines(list_path, on_file_list_line, &ctx);
    if (!pkg->install_location[0] && ctx.first_binary[0])
        mi_copy_str(pkg->install_location, sizeof(pkg->install_location), ctx.first_binary);
    if (!pkg->icon_path[0]) apply_desktop_entry(pkg, find_by_id(index, pkg->name));
}

typedef struct {
    mi_package_list *out;
    const desktop_index *index;
    mi_package current;
    char architecture[32];
    int installed;
} dpkg_ctx;

static void flush_dpkg(dpkg_ctx *c)
{
    if (c->installed && c->current.name[0]) {
        char list[MI_STR_LARGE];
        snprintf(list, sizeof(list), "/var/lib/dpkg/info/%s.list", c->current.name);
        if (!path_exists(list) && c->architecture[0])
            snprintf(list, sizeof(list), "/var/lib/dpkg/info/%s:%s.list", c->current.name, c->architecture);
        enrich_from_file_list(&c->current, c->index, list);
        set_uninstall(&c->current, "pkexec apt-get remove -y", c->current.name);
        mi_package *p = mi_package_list_push(c->out);
        if (p) *p = c->current;
    }
    memset(&c->current, 0, sizeof(c->current));
    mi_copy_str(c->current.source, sizeof(c->current.source), "dpkg");
    c->architecture[0] = '\0';
    c->installed = 0;
}

static void on_dpkg_line(char *line, void *ctx)
{
    dpkg_ctx *c = ctx;
    if (line[0] == '\0') {
        flush_dpkg(c);
        return;
    }
    if (line[0] == ' ') return;
    char *key, *value;
    if (!mi_split_key_value(line, ':', &key, &value)) return;
    if (strcmp(key, "Package") == 0) mi_copy_str(c->current.name, sizeof(c->current.name), value);
    else if (strcmp(key, "Version") == 0) mi_copy_str(c->current.version, sizeof(c->current.version), value);
    else if (strcmp(key, "Maintainer") == 0) mi_copy_str(c->current.publisher, sizeof(c->current.publisher), value);
    else if (strcmp(key, "Architecture") == 0) mi_copy_str(c->architecture, sizeof(c->architecture), value);
    else if (strcmp(key, "Installed-Size") == 0) c->current.size_bytes = strtoull(value, NULL, 10) * 1024u;
    else if (strcmp(key, "Status") == 0) c->installed = strstr(value, "installed") && !strstr(value, "not-installed") && !strstr(value, "config-files");
}

static int read_dpkg(mi_package_list *out, const desktop_index *index)
{
    dpkg_ctx *ctx = calloc(1, sizeof(dpkg_ctx));
    if (!ctx) return 0;
    ctx->out = out;
    ctx->index = index;
    flush_dpkg(ctx);
    int ok = mi_read_file_lines("/var/lib/dpkg/status", on_dpkg_line, ctx) >= 0;
    if (ok) flush_dpkg(ctx);
    free(ctx);
    return ok;
}

typedef struct {
    mi_package_list *out;
    const desktop_index *index;
    const char *remove_prefix;
} rpm_ctx;

static void on_rpm_line(char *line, void *ctx)
{
    rpm_ctx *c = ctx;
    char *fields[4] = {line, "", "", ""};
    for (int i = 1; i < 4; i++) {
        char *tab = strchr(fields[i - 1], '\t');
        if (!tab) break;
        *tab = '\0';
        fields[i] = tab + 1;
    }
    mi_package *p = mi_package_list_push(c->out);
    if (!p) return;
    mi_copy_str(p->name, sizeof(p->name), fields[0]);
    mi_copy_str(p->version, sizeof(p->version), fields[1]);
    mi_copy_str(p->publisher, sizeof(p->publisher), strcmp(fields[2], "(none)") == 0 ? "" : fields[2]);
    mi_copy_str(p->source, sizeof(p->source), "rpm");
    p->size_bytes = strtoull(fields[3], NULL, 10);
    apply_desktop_entry(p, find_by_id(c->index, p->name));
    set_uninstall(p, c->remove_prefix, p->name);
}

static int read_rpm(mi_package_list *out, const desktop_index *index)
{
    if (!mi_command_exists("rpm") || access("/var/lib/rpm", F_OK) != 0) return 0;
    rpm_ctx ctx = {out, index, mi_command_exists("dnf") ? "pkexec dnf remove -y" : "pkexec rpm -e"};
    return mi_run_command_lines("rpm -qa --queryformat '%{NAME}\\t%{VERSION}-%{RELEASE}\\t%{VENDOR}\\t%{SIZE}\\n'",
                                on_rpm_line, &ctx) >= 0;
}

typedef struct {
    mi_package *pkg;
    char section[32];
} pacman_ctx;

static void on_pacman_desc(char *line, void *ctx)
{
    pacman_ctx *c = ctx;
    if (line[0] == '%') {
        mi_copy_str(c->section, sizeof(c->section), line);
        return;
    }
    if (line[0] == '\0') {
        c->section[0] = '\0';
        return;
    }
    if (strcmp(c->section, "%NAME%") == 0) mi_copy_str(c->pkg->name, sizeof(c->pkg->name), line);
    else if (strcmp(c->section, "%VERSION%") == 0) mi_copy_str(c->pkg->version, sizeof(c->pkg->version), line);
    else if (strcmp(c->section, "%PACKAGER%") == 0) mi_copy_str(c->pkg->publisher, sizeof(c->pkg->publisher), line);
    else if (strcmp(c->section, "%SIZE%") == 0) c->pkg->size_bytes = strtoull(line, NULL, 10);
    c->section[0] = '\0';
}

static int read_pacman(mi_package_list *out, const desktop_index *index)
{
    DIR *d = opendir("/var/lib/pacman/local");
    if (!d) return 0;
    mi_package *pkg = malloc(sizeof(mi_package));
    if (!pkg) {
        closedir(d);
        return 0;
    }
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        if (e->d_name[0] == '.') continue;
        char path[1024];
        snprintf(path, sizeof(path), "/var/lib/pacman/local/%s/desc", e->d_name);
        memset(pkg, 0, sizeof(*pkg));
        pacman_ctx ctx = {.pkg = pkg};
        if (mi_read_file_lines(path, on_pacman_desc, &ctx) < 0) continue;
        mi_copy_str(pkg->source, sizeof(pkg->source), "pacman");
        snprintf(path, sizeof(path), "/var/lib/pacman/local/%s/files", e->d_name);
        enrich_from_file_list(pkg, index, path);
        set_uninstall(pkg, "pkexec pacman -R --noconfirm", pkg->name);
        mi_package *p = mi_package_list_push(out);
        if (p) *p = *pkg;
    }
    free(pkg);
    closedir(d);
    return 1;
}

static void flatpak_location(const char *id, char *out, size_t out_size)
{
    char candidate[MI_STR_LARGE];
    snprintf(candidate, sizeof(candidate), "/var/lib/flatpak/app/%s/current/active", id);
    if (is_directory(candidate)) {
        mi_copy_str(out, out_size, candidate);
        return;
    }
    const char *home = getenv("HOME");
    if (!home) return;
    snprintf(candidate, sizeof(candidate), "%s/.local/share/flatpak/app/%s/current/active", home, id);
    if (is_directory(candidate)) mi_copy_str(out, out_size, candidate);
}

static void on_flatpak_line(char *line, void *ctx)
{
    mi_package_list *out = ctx;
    char *fields[4] = {line, "", "", ""};
    for (int i = 1; i < 4; i++) {
        char *tab = strchr(fields[i - 1], '\t');
        if (!tab) break;
        *tab = '\0';
        fields[i] = tab + 1;
    }
    if (!fields[0][0]) return;

    mi_package *p = mi_package_list_push(out);
    if (!p) return;
    mi_copy_str(p->name, sizeof(p->name), fields[0]);
    mi_copy_str(p->version, sizeof(p->version), fields[1]);
    mi_copy_str(p->publisher, sizeof(p->publisher), fields[2]);
    mi_copy_str(p->source, sizeof(p->source), "flatpak");
    const char *id = fields[3][0] ? fields[3] : fields[0];
    flatpak_location(id, p->install_location, sizeof(p->install_location));
    resolve_icon(id, p->icon_path, sizeof(p->icon_path));
    set_uninstall(p, "flatpak uninstall -y", id);
}

static int read_flatpak(mi_package_list *out)
{
    if (!mi_command_exists("flatpak")) return 0;
    return mi_run_command_lines("flatpak list --app --columns=name,version,origin,application", on_flatpak_line, out) >= 0;
}

typedef struct {
    mi_package_list *out;
    const desktop_index *index;
    int header_skipped;
} snap_ctx;

static void on_snap_line(char *line, void *ctx)
{
    snap_ctx *c = ctx;
    if (!c->header_skipped) {
        c->header_skipped = 1;
        return;
    }
    char name[MI_STR_MEDIUM], version[MI_STR_SMALL], rev[32], tracking[64], publisher[MI_STR_MEDIUM];
    if (sscanf(line, "%255s %63s %31s %63s %255s", name, version, rev, tracking, publisher) < 2) return;
    mi_package *p = mi_package_list_push(c->out);
    if (!p) return;
    mi_copy_str(p->name, sizeof(p->name), name);
    mi_copy_str(p->version, sizeof(p->version), version);
    mi_copy_str(p->publisher, sizeof(p->publisher), publisher);
    mi_copy_str(p->source, sizeof(p->source), "snap");
    snprintf(p->install_location, sizeof(p->install_location), "/snap/%s/current", name);

    char icon[MI_STR_LARGE];
    snprintf(icon, sizeof(icon), "/snap/%s/current/meta/gui/icon.png", name);
    if (path_exists(icon)) mi_copy_str(p->icon_path, sizeof(p->icon_path), icon);
    else apply_desktop_entry(p, find_by_id(c->index, name));
    set_uninstall(p, "pkexec snap remove", name);
}

static int read_snap(mi_package_list *out, const desktop_index *index)
{
    if (!mi_command_exists("snap")) return 0;
    snap_ctx ctx = {.out = out, .index = index};
    return mi_run_command_lines("snap list", on_snap_line, &ctx) >= 0;
}

static mi_status linux_list_installed(mi_package_list *out)
{
    desktop_index index;
    build_desktop_index(&index);
    int sources = 0;
    sources += read_dpkg(out, &index);
    sources += read_rpm(out, &index);
    sources += read_pacman(out, &index);
    sources += read_flatpak(out);
    sources += read_snap(out, &index);
    free(index.items);
    return sources > 0 ? MI_OK : MI_ERR_UNSUPPORTED;
}

static const mi_software_port LINUX_SOFTWARE = {
    .platform = "linux",
    .list_installed = linux_list_installed,
    .extract_icon_png = NULL,
    .launch_uninstaller = NULL,
};

const mi_software_port *mi_linux_software_port(void)
{
    return &LINUX_SOFTWARE;
}
