#include <stdio.h>
#include <string.h>

#include "machineinfo/machineinfo.h"

int main(int argc, char **argv)
{
    if (argc > 1 && (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0)) {
        printf("machineinfo %s\n", mi_version());
        printf("usage: machineinfo-cli [os|cpu|memory|disks|temperatures|software|hardware|all]\n");
        return 0;
    }

    char *json = mi_collect_json(argc > 1 ? argv[1] : "all");
    if (!json) {
        fprintf(stderr, "failed to collect information\n");
        return 1;
    }
    puts(json);
    mi_free_string(json);
    return 0;
}
