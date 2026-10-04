#include "png_writer.h"

#include <stdlib.h>
#include <string.h>

static uint32_t crc_table[256];
static int crc_ready = 0;

static void build_crc_table(void)
{
    for (uint32_t n = 0; n < 256; n++) {
        uint32_t c = n;
        for (int k = 0; k < 8; k++) c = (c & 1) ? 0xEDB88320u ^ (c >> 1) : c >> 1;
        crc_table[n] = c;
    }
    crc_ready = 1;
}

static uint32_t crc32_update(uint32_t crc, const unsigned char *data, size_t len)
{
    if (!crc_ready) build_crc_table();
    for (size_t i = 0; i < len; i++) crc = crc_table[(crc ^ data[i]) & 0xFF] ^ (crc >> 8);
    return crc;
}

static void put_u32(unsigned char *p, uint32_t v)
{
    p[0] = (unsigned char)(v >> 24);
    p[1] = (unsigned char)(v >> 16);
    p[2] = (unsigned char)(v >> 8);
    p[3] = (unsigned char)v;
}

static unsigned char *write_chunk(unsigned char *p, const char *type, const unsigned char *data, size_t len)
{
    put_u32(p, (uint32_t)len);
    memcpy(p + 4, type, 4);
    if (len) memcpy(p + 8, data, len);
    uint32_t crc = crc32_update(0xFFFFFFFFu, p + 4, len + 4) ^ 0xFFFFFFFFu;
    put_u32(p + 8 + len, crc);
    return p + 12 + len;
}

mi_status mi_png_encode_rgba(const unsigned char *rgba, int width, int height, mi_buffer *out)
{
    out->data = NULL;
    out->length = 0;
    if (!rgba || width <= 0 || height <= 0 || width > 4096 || height > 4096) return MI_ERR_IO;

    size_t row = (size_t)width * 4 + 1;
    size_t raw_len = row * (size_t)height;
    size_t blocks = raw_len / 65535 + 1;
    size_t zlen = 2 + raw_len + blocks * 5 + 4;
    unsigned char *z = malloc(zlen);
    unsigned char *raw = malloc(raw_len);
    if (!z || !raw) {
        free(z);
        free(raw);
        return MI_ERR_NO_MEMORY;
    }

    for (int y = 0; y < height; y++) {
        raw[(size_t)y * row] = 0;
        memcpy(raw + (size_t)y * row + 1, rgba + (size_t)y * width * 4, (size_t)width * 4);
    }

    unsigned char *zp = z;
    *zp++ = 0x78;
    *zp++ = 0x01;
    size_t remaining = raw_len, offset = 0;
    uint32_t a = 1, b = 0;
    do {
        size_t n = remaining > 65535 ? 65535 : remaining;
        *zp++ = remaining <= 65535 ? 1 : 0;
        *zp++ = (unsigned char)(n & 0xFF);
        *zp++ = (unsigned char)(n >> 8);
        *zp++ = (unsigned char)(~n & 0xFF);
        *zp++ = (unsigned char)((~n >> 8) & 0xFF);
        memcpy(zp, raw + offset, n);
        for (size_t i = 0; i < n; i++) {
            a = (a + raw[offset + i]) % 65521;
            b = (b + a) % 65521;
        }
        zp += n;
        offset += n;
        remaining -= n;
    } while (remaining > 0);
    put_u32(zp, (b << 16) | a);
    zp += 4;
    size_t idat_len = (size_t)(zp - z);
    free(raw);

    size_t total = 8 + (12 + 13) + (12 + idat_len) + 12;
    unsigned char *png = malloc(total);
    if (!png) {
        free(z);
        return MI_ERR_NO_MEMORY;
    }
    static const unsigned char signature[8] = {0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n'};
    memcpy(png, signature, 8);
    unsigned char ihdr[13];
    put_u32(ihdr, (uint32_t)width);
    put_u32(ihdr + 4, (uint32_t)height);
    ihdr[8] = 8;
    ihdr[9] = 6;
    ihdr[10] = 0;
    ihdr[11] = 0;
    ihdr[12] = 0;
    unsigned char *p = write_chunk(png + 8, "IHDR", ihdr, sizeof(ihdr));
    p = write_chunk(p, "IDAT", z, idat_len);
    write_chunk(p, "IEND", NULL, 0);
    free(z);

    out->data = png;
    out->length = total;
    return MI_OK;
}
