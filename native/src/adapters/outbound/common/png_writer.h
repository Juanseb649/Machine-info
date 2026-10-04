#ifndef MI_PNG_WRITER_H
#define MI_PNG_WRITER_H

#include "../../../domain/models.h"

mi_status mi_png_encode_rgba(const unsigned char *rgba, int width, int height, mi_buffer *out);

#endif
