#include <stdint.h>
#include <string.h>

#include <IOKit/IOKitLib.h>

#include "../../../domain/models.h"

#define SMC_KERNEL_INDEX 2
#define SMC_CMD_READ_BYTES 5
#define SMC_CMD_READ_KEYINFO 9

typedef struct {
    char major;
    char minor;
    char build;
    char reserved;
    uint16_t release;
} smc_version;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpu_limit;
    uint32_t gpu_limit;
    uint32_t mem_limit;
} smc_limit_data;

typedef struct {
    uint32_t data_size;
    uint32_t data_type;
    char data_attributes;
} smc_key_info;

typedef struct {
    uint32_t key;
    smc_version version;
    smc_limit_data limit_data;
    smc_key_info key_info;
    char result;
    char status;
    char data8;
    uint32_t data32;
    unsigned char bytes[32];
} smc_param;

typedef struct {
    const char *key;
    const char *label;
} smc_sensor;

static const smc_sensor SENSORS[] = {
    {"TC0P", "CPU proximity"},
    {"TC0D", "CPU die"},
    {"TC0E", "CPU die (virtual)"},
    {"TC0F", "CPU die (filtered)"},
    {"TCXC", "CPU PECI"},
    {"TG0P", "GPU proximity"},
    {"TG0D", "GPU die"},
    {"TA0P", "Ambient"},
    {"TB0T", "Battery"},
    {"TM0P", "Memory proximity"},
    {"Ts0P", "Palm rest"},
    {"Tp09", "CPU efficiency core 1"},
    {"Tp0T", "CPU efficiency core 2"},
    {"Tp01", "CPU performance core 1"},
    {"Tp05", "CPU performance core 2"},
    {"Tp0D", "CPU performance core 3"},
    {"Tp0H", "CPU performance core 4"},
    {"Tp0L", "CPU performance core 5"},
    {"Tp0P", "CPU performance core 6"},
    {"Tp0X", "CPU performance core 7"},
    {"Tp0b", "CPU performance core 8"},
    {"Tg05", "GPU 1"},
    {"Tg0D", "GPU 2"},
    {"Tg0L", "GPU 3"},
    {"Tg0T", "GPU 4"},
    {"TaLP", "Airflow left"},
    {"TaRF", "Airflow right"},
    {"TH0x", "NAND"},
};

static uint32_t fourcc(const char *s)
{
    return ((uint32_t)(unsigned char)s[0] << 24) | ((uint32_t)(unsigned char)s[1] << 16) |
           ((uint32_t)(unsigned char)s[2] << 8) | (uint32_t)(unsigned char)s[3];
}

static kern_return_t smc_call(io_connect_t conn, smc_param *in, smc_param *out)
{
    size_t out_size = sizeof(smc_param);
    return IOConnectCallStructMethod(conn, SMC_KERNEL_INDEX, in, sizeof(smc_param), out, &out_size);
}

static int smc_read(io_connect_t conn, const char *key, double *celsius)
{
    smc_param in, out;
    memset(&in, 0, sizeof(in));
    memset(&out, 0, sizeof(out));
    in.key = fourcc(key);
    in.data8 = SMC_CMD_READ_KEYINFO;
    if (smc_call(conn, &in, &out) != KERN_SUCCESS || out.result != 0) return 0;

    uint32_t size = out.key_info.data_size;
    uint32_t type = out.key_info.data_type;
    if (size == 0 || size > 32) return 0;

    in.key_info.data_size = size;
    in.data8 = SMC_CMD_READ_BYTES;
    memset(&out, 0, sizeof(out));
    if (smc_call(conn, &in, &out) != KERN_SUCCESS || out.result != 0) return 0;

    if (type == fourcc("sp78") && size >= 2) {
        int16_t raw = (int16_t)(((uint16_t)out.bytes[0] << 8) | out.bytes[1]);
        *celsius = raw / 256.0;
        return 1;
    }
    if (type == fourcc("flt ") && size >= 4) {
        float value;
        memcpy(&value, out.bytes, sizeof(value));
        *celsius = value;
        return 1;
    }
    return 0;
}

mi_status mi_macos_read_smc_temperatures(mi_temperature_list *out)
{
    io_service_t service = IOServiceGetMatchingService(MACH_PORT_NULL,IOServiceMatching("AppleSMC"));
    if (!service) return MI_ERR_UNSUPPORTED;

    io_connect_t conn = 0;
    kern_return_t rc = IOServiceOpen(service, mach_task_self(), 0, &conn);
    IOObjectRelease(service);
    if (rc != KERN_SUCCESS) return MI_ERR_PERMISSION;

    for (size_t i = 0; i < sizeof(SENSORS) / sizeof(SENSORS[0]); i++) {
        double celsius = 0;
        if (!smc_read(conn, SENSORS[i].key, &celsius) || celsius <= 0) continue;
        mi_temperature *t = mi_temperature_list_push(out);
        if (!t) break;
        mi_copy_str(t->label, sizeof(t->label), SENSORS[i].label);
        mi_copy_str(t->source, sizeof(t->source), "smc");
        t->celsius = celsius;
    }
    IOServiceClose(conn);
    return out->count > 0 ? MI_OK : MI_ERR_UNSUPPORTED;
}
