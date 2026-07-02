/* crc32c_mex.c - fast CRC-32C (Castagnoli) for zarr-matlab.
 *
 *   crc = crc32c_mex(uint8vec)   -> uint32 scalar
 *
 * Slicing-by-4 table implementation; self-contained.
 */
#include <stdint.h>
#include <string.h>
#include "mex.h"

#define POLY 0x82F63B78u

static uint32_t table[4][256];
static int initialized = 0;

static void init_tables(void)
{
    for (int i = 0; i < 256; i++) {
        uint32_t c = (uint32_t)i;
        for (int k = 0; k < 8; k++)
            c = (c & 1) ? (c >> 1) ^ POLY : c >> 1;
        table[0][i] = c;
    }
    for (int i = 0; i < 256; i++) {
        uint32_t c = table[0][i];
        for (int t = 1; t < 4; t++) {
            c = (c >> 8) ^ table[0][c & 0xFF];
            table[t][i] = c;
        }
    }
    initialized = 1;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    (void)nlhs;
    if (nrhs != 1 || !mxIsUint8(prhs[0]))
        mexErrMsgIdAndTxt("zarr:InternalError", "usage: crc32c_mex(uint8vec)");
    if (!initialized)
        init_tables();

    const uint8_t *p = (const uint8_t *)mxGetData(prhs[0]);
    size_t n = mxGetNumberOfElements(prhs[0]);
    uint32_t crc = 0xFFFFFFFFu;

    while (n >= 4) {
        uint32_t w;
        memcpy(&w, p, 4);
        crc ^= w;  /* little-endian only (all supported MATLAB platforms) */
        crc = table[3][crc & 0xFF] ^ table[2][(crc >> 8) & 0xFF] ^
              table[1][(crc >> 16) & 0xFF] ^ table[0][crc >> 24];
        p += 4;
        n -= 4;
    }
    while (n--) {
        crc = (crc >> 8) ^ table[0][(crc ^ *p++) & 0xFF];
    }
    crc ^= 0xFFFFFFFFu;

    plhs[0] = mxCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
    *(uint32_t *)mxGetData(plhs[0]) = crc;
}
