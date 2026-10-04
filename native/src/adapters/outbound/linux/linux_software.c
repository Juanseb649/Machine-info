#define _GNU_SOURCE
#include <dirent.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "../../../ports/software_port.h"
#include "../common/text_utils.h"

typedef struct {
    mi_package_list *out;
    mi_package current;
    int installed;
} dpkg_ctx;

static void flush_dpkg(dpkg_ctx *c)
{
    if (c->installed && c->current.name[0]) {
        mi_package *p = mi_package_list_push(c->out);
        if (p) *p = c->current;
    }
    memset(&c->current, 0, sizeof(c->current));
    mi_copy_str(c->current.source, sizeof(c->current.source), "dpkg");
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
    else if (strcmp(key, "Status") == 0) c->installed = strstr(value, "installed") && !strstr(value, "not-installed") && !strstr(value, "config-files");
}

static int read_dpkg(mi_package_list *out)
{
    dpkg_ctx ctx = {.out = out};
    flush_dpkg(&ctx);
    if (mi_read_file_lines("/var/lib/dpkg/status", on_dpkg_line, &ctx) < 0) return 0;
    flush_dpkg(&ctx);
    return 1;
}

static void on_rpm_line(char *line, void *ctx)
{
    mi_package_list *out = ctx;
    char *fields[3] = {line, "", ""};
    for (int i = 1; i < 3; i++) {
        char *tab = strchr(fields[i - 1], '\t');
        if (!tab) break;
        *tab = '\0';
        fields[i] = tab + 1;
    }
    mi_package *p = mi_package_list_push(out);
    if (!p) return;
    mi_copy_str(p->name, sizeof(p->name), fields[0]);
    mi_copy_str(p->version, sizeof(p->version), fields[1]);
    mi_copy_str(p->publisher, sizeof(p->publisher), strcmp(fields[2], "(none)") == 0 ? "" : fields[2]);
    mi_copy_str(p->source, sizeof(p->source), "rpm");
}

static int read_rpm(mi_package_list *out)
{
    if (!mi_command_exists("rpm") || access("/var/lib/rpm", F_OK) != 0) return 0;
    return mi_run_command_lines("rpm -qa --queryformat '%{NAME}\\t%{VERSION}-%{RELEASE}\\t%{VENDOR}\\n'",
                                on_rpm_line, out) >= 0;
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
    c->section[0] = '\0';
}

static int read_pacman(mi_package_list *out)
{
    DIR *d = opendir("/var/lib/pacman/local");
    if (!d) return 0;
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        if (e->d_name[0] == '.') continue;
        char path[1024];
        snprintf(path, sizeof(path), "/var/lib/pacman/local/%s/desc", e->d_name);
        mi_package pkg = {0};
        pacman_ctx ctx = {.pkg = &pkg};
        if (mi_read_file_lines(path, on_pacman_desc, &ctx) < 0) continue;
        mi_copy_str(pkg.source, sizeof(pkg.source), "pacman");
        mi_package *p = mi_package_list_push(out);
        if (p) *p = pkg;
    }
    closedir(d);
    return 1;
}

static void on_flatpak_line(char *line, void *ctx)
{
    mi_package_list *out = ctx;
    char *name = line;
    char *version = strchr(name, '\t');
    if (!version) return;
    *version++ = '\0';
    char *origin = strchr(version, '\t');
    if (origin) *origin++ = '\0';

    mi_package *p = mi_package_list_push(out);
    if (!p) return;
    mi_copy_str(p->name, sizeof(p->name), name);
    mi_copy_str(p->version, sizeof(p->version), version);
    mi_copy_str(p->publisher, sizeof(p->publisher), origin ? origin : "");
    mi_copy_str(p->source, sizeof(p->source), "flatpak");
}

static int read_flatpak(mi_package_list *out)
{
    if (!mi_command_exists("flatpak")) return 0;
    return mi_run_command_lines("flatpak list --app --columns=name,version,origin", on_flatpak_line, out) >= 0;
}

typedef struct {
    mi_package_list *out;
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
}

static int read_snap(mi_package_list *out)
{
    if (!mi_command_exists("snap")) return 0;
    snap_ctx ctx = {.out = out};
    return mi_run_command_lines("snap list", on_snap_line, &ctx) >= 0;
}

static mi_status linux_list_installed(mi_package_list *out)
{
    int sources = 0;
    sources += read_dpkg(out);
    sources += read_rpm(out);
    sources += read_pacman(out);
    sources += read_flatpak(out);
    sources += read_snap(out);
    return sources > 0 ? MI_OK : MI_ERR_UNSUPPORTED;
}

static const mi_software_port LINUX_SOFTWARE = {
    .platform = "linux",
    .list_installed = linux_list_installed,
};

const mi_software_port *mi_linux_software_port(void)
{
    return &LINUX_SOFTWARE;
}
