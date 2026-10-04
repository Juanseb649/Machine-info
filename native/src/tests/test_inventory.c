#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "adapters/inbound/json/report_presenter.h"
#include "adapters/outbound/common/png_writer.h"
#include "application/inventory_service.h"
#include "fake_adapters.h"

static int failures = 0;

#define CHECK(cond)                                                    \
    do {                                                               \
        if (!(cond)) {                                                 \
            fprintf(stderr, "FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond); \
            failures++;                                                \
        }                                                              \
    } while (0)

static void test_normalization(void)
{
    mi_inventory_service svc;
    mi_inventory_init(&svc, fake_hardware_port(), fake_software_port());
    mi_report r;
    mi_inventory_collect(&svc, MI_SECTION_ALL, &r);

    CHECK(strcmp(r.platform, "fake") == 0);
    CHECK(strcmp(r.cpu.model, "Fake CPU 9000") == 0);
    CHECK(r.cpu.physical_cores == 8);
    CHECK(r.cpu.usage_percent == 100.0);
    CHECK(r.memory.used_bytes == 12000);
    CHECK(r.disks.count == 1);
    CHECK(r.disks.items[0].used_bytes == 750);
    CHECK(r.temperatures.count == 1);
    CHECK(r.software.count == 3);
    CHECK(strcmp(r.software.items[0].name, "Bash") == 0);
    CHECK(strcmp(r.software.items[1].name, "Git") == 0 || strcmp(r.software.items[1].name, "git") == 0);
    CHECK(strcmp(r.software.items[2].name, "zsh") == 0);

    mi_report_free(&r);
}

static void test_section_selection(void)
{
    mi_inventory_service svc;
    mi_inventory_init(&svc, fake_hardware_port(), fake_software_port());
    mi_report r;
    mi_inventory_collect(&svc, mi_section_from_name("memory"), &r);

    char *json = mi_present_report_json(&r);
    CHECK(json != NULL);
    CHECK(strstr(json, "\"memory\":{\"status\":\"ok\"") != NULL);
    CHECK(strstr(json, "\"cpu\"") == NULL);
    CHECK(strstr(json, "\"software\"") == NULL);
    free(json);
    mi_report_free(&r);

    CHECK(mi_section_from_name("HARDWARE") == MI_SECTION_HARDWARE);
    CHECK(mi_section_from_name("nope") == 0);
    CHECK(mi_section_from_name(NULL) == MI_SECTION_ALL);
}

static void test_unsupported_ports(void)
{
    mi_inventory_service svc;
    mi_inventory_init(&svc, failing_hardware_port(), NULL);
    mi_report r;
    mi_inventory_collect(&svc, MI_SECTION_ALL, &r);

    CHECK(r.cpu_status == MI_ERR_UNSUPPORTED);
    CHECK(r.os_status == MI_ERR_UNSUPPORTED);
    CHECK(r.software_status == MI_ERR_UNSUPPORTED);

    char *json = mi_present_report_json(&r);
    CHECK(strstr(json, "\"cpu\":{\"status\":\"unsupported\",\"data\":null}") != NULL);
    CHECK(strstr(json, "\"software\":{\"status\":\"unsupported\",\"data\":[]}") != NULL);
    free(json);
    mi_report_free(&r);
}

static void test_json_escaping(void)
{
    mi_inventory_service svc;
    mi_inventory_init(&svc, fake_hardware_port(), NULL);
    mi_report r;
    mi_inventory_collect(&svc, MI_SECTION_OS | MI_SECTION_CPU, &r);
    char *json = mi_present_report_json(&r);
    CHECK(strstr(json, "FakeOS \\\"Test\\\"") != NULL);
    CHECK(strstr(json, "\"baseFrequencyMhz\":3200.50") != NULL);
    free(json);
    mi_report_free(&r);
}

static void test_software_details(void)
{
    mi_inventory_service svc;
    mi_inventory_init(&svc, fake_hardware_port(), fake_software_port());
    mi_report r;
    mi_inventory_collect(&svc, MI_SECTION_SOFTWARE, &r);
    char *json = mi_present_report_json(&r);
    CHECK(strstr(json, "\"installLocation\":\"C:\\\\Program Files\\\\Git\"") != NULL);
    CHECK(strstr(json, "\"uninstallCommand\":\"\\\"C:") != NULL);
    CHECK(strstr(json, "\"sizeBytes\":2048") != NULL);
    free(json);
    mi_report_free(&r);
}

static void test_png_writer(void)
{
    unsigned char pixels[3 * 2 * 4];
    for (size_t i = 0; i < sizeof(pixels); i++) pixels[i] = (unsigned char)(i * 7);
    mi_buffer png = {0};
    CHECK(mi_png_encode_rgba(pixels, 3, 2, &png) == MI_OK);
    CHECK(png.length > 8 + 25 + 12 + 12);
    CHECK(memcmp(png.data, "\x89PNG\r\n\x1a\n", 8) == 0);
    CHECK(memcmp(png.data + 12, "IHDR", 4) == 0);
    CHECK(memcmp(png.data + png.length - 8, "IEND", 4) == 0);
    mi_buffer_free(&png);
    CHECK(png.data == NULL);
    CHECK(mi_png_encode_rgba(pixels, 0, 2, &png) != MI_OK);
}

int main(void)
{
    test_normalization();
    test_section_selection();
    test_unsupported_ports();
    test_json_escaping();
    test_software_details();
    test_png_writer();
    if (failures) {
        fprintf(stderr, "%d check(s) failed\n", failures);
        return 1;
    }
    printf("all tests passed\n");
    return 0;
}
