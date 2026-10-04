#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <CoreFoundation/CoreFoundation.h>

#include "../../../ports/software_port.h"
#include "../common/text_utils.h"

static int ends_with(const char *s, const char *suffix)
{
    size_t ls = strlen(s), lf = strlen(suffix);
    return ls >= lf && strcmp(s + ls - lf, suffix) == 0;
}

static void cf_to_utf8(CFTypeRef value, char *out, size_t out_size)
{
    out[0] = '\0';
    if (value && CFGetTypeID(value) == CFStringGetTypeID())
        CFStringGetCString((CFStringRef)value, out, (CFIndex)out_size, kCFStringEncodingUTF8);
}

static void read_bundle(const char *path, const char *fallback_name, const char *source, mi_package_list *out)
{
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (const UInt8 *)path,
                                                           (CFIndex)strlen(path), true);
    if (!url) return;
    CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, url);
    CFRelease(url);
    if (!bundle) return;

    mi_package *p = mi_package_list_push(out);
    if (p) {
        cf_to_utf8(CFBundleGetValueForInfoDictionaryKey(bundle, CFSTR("CFBundleDisplayName")), p->name, sizeof(p->name));
        if (!p->name[0]) cf_to_utf8(CFBundleGetValueForInfoDictionaryKey(bundle, CFSTR("CFBundleName")), p->name, sizeof(p->name));
        if (!p->name[0]) mi_copy_str(p->name, sizeof(p->name), fallback_name);
        cf_to_utf8(CFBundleGetValueForInfoDictionaryKey(bundle, CFSTR("CFBundleShortVersionString")), p->version, sizeof(p->version));
        if (!p->version[0]) cf_to_utf8(CFBundleGetValueForInfoDictionaryKey(bundle, kCFBundleVersionKey), p->version, sizeof(p->version));
        cf_to_utf8(CFBundleGetIdentifier(bundle), p->publisher, sizeof(p->publisher));
        mi_copy_str(p->source, sizeof(p->source), source);
    }
    CFRelease(bundle);
}

static int scan_applications(const char *dir, const char *source, int depth, mi_package_list *out)
{
    DIR *d = opendir(dir);
    if (!d) return 0;
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        if (e->d_name[0] == '.') continue;
        char path[2048];
        snprintf(path, sizeof(path), "%s/%s", dir, e->d_name);
        if (ends_with(e->d_name, ".app")) {
            char name[MI_STR_MEDIUM];
            mi_copy_str(name, sizeof(name), e->d_name);
            name[strlen(name) - 4] = '\0';
            read_bundle(path, name, source, out);
        } else if (depth > 0 && e->d_type == DT_DIR) {
            scan_applications(path, source, depth - 1, out);
        }
    }
    closedir(d);
    return 1;
}

typedef struct {
    mi_package_list *out;
    const char *source;
} brew_ctx;

static void on_brew_line(char *line, void *ctx)
{
    brew_ctx *c = ctx;
    char *space = strchr(line, ' ');
    mi_package *p = mi_package_list_push(c->out);
    if (!p) return;
    if (space) {
        *space = '\0';
        char *last = strrchr(space + 1, ' ');
        mi_copy_str(p->version, sizeof(p->version), last ? last + 1 : space + 1);
    }
    mi_copy_str(p->name, sizeof(p->name), line);
    mi_copy_str(p->publisher, sizeof(p->publisher), "Homebrew");
    mi_copy_str(p->source, sizeof(p->source), c->source);
}

static const char *find_brew(void)
{
    static const char *candidates[] = {"/opt/homebrew/bin/brew", "/usr/local/bin/brew", NULL};
    for (int i = 0; candidates[i]; i++)
        if (access(candidates[i], X_OK) == 0) return candidates[i];
    return NULL;
}

static int read_homebrew(mi_package_list *out)
{
    const char *brew = find_brew();
    if (!brew) return 0;
    char command[512];
    brew_ctx formulae = {out, "homebrew"};
    brew_ctx casks = {out, "homebrew-cask"};
    snprintf(command, sizeof(command), "HOMEBREW_NO_AUTO_UPDATE=1 '%s' list --formula --versions", brew);
    int ok = mi_run_command_lines(command, on_brew_line, &formulae) >= 0;
    snprintf(command, sizeof(command), "HOMEBREW_NO_AUTO_UPDATE=1 '%s' list --cask --versions", brew);
    ok |= mi_run_command_lines(command, on_brew_line, &casks) >= 0;
    return ok;
}

static mi_status macos_list_installed(mi_package_list *out)
{
    int sources = 0;
    sources += scan_applications("/Applications", "applications", 1, out);
    sources += scan_applications("/System/Applications", "system", 1, out);

    const char *home = getenv("HOME");
    if (home) {
        char user_apps[1024];
        snprintf(user_apps, sizeof(user_apps), "%s/Applications", home);
        sources += scan_applications(user_apps, "user", 1, out);
    }
    sources += read_homebrew(out);
    return sources > 0 ? MI_OK : MI_ERR_UNSUPPORTED;
}

static const mi_software_port MACOS_SOFTWARE = {
    .platform = "macos",
    .list_installed = macos_list_installed,
};

const mi_software_port *mi_macos_software_port(void)
{
    return &MACOS_SOFTWARE;
}
