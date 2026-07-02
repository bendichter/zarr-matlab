/* blosc_mex.c - Blosc(1) codec for zarr-matlab, matching numcodecs framing.
 *
 *   out = blosc_mex('compress',   uint8vec, cname, clevel, shuffle, typesize)
 *   out = blosc_mex('decompress', uint8vec)
 *
 *   shuffle: 0 = noshuffle, 1 = byte shuffle, 2 = bitshuffle
 */
#include <stdint.h>
#include <string.h>
#include <blosc.h>
#include "mex.h"

static void do_compress(const mxArray *prhs[], mxArray *plhs[])
{
    const uint8_t *in = (const uint8_t *)mxGetData(prhs[1]);
    size_t inLen = mxGetNumberOfElements(prhs[1]);
    char cname[32];
    if (mxGetString(prhs[2], cname, sizeof(cname)) != 0)
        mexErrMsgIdAndTxt("zarr:CodecError", "blosc_mex: bad cname");
    int clevel = (int)mxGetScalar(prhs[3]);
    int shuffle = (int)mxGetScalar(prhs[4]);
    size_t typesize = (size_t)mxGetScalar(prhs[5]);
    if (typesize < 1) typesize = 1;

    size_t destSize = inLen + BLOSC_MAX_OVERHEAD;
    uint8_t *tmp = (uint8_t *)mxMalloc(destSize);
    int n = blosc_compress_ctx(clevel, shuffle, typesize, inLen, in,
                               tmp, destSize, cname, 0 /* auto blocksize */,
                               1 /* threads */);
    if (n <= 0) {
        mxFree(tmp);
        mexErrMsgIdAndTxt("zarr:CodecError", "blosc: compression failed (%d)", n);
    }
    plhs[0] = mxCreateNumericMatrix(1, (mwSize)n, mxUINT8_CLASS, mxREAL);
    memcpy(mxGetData(plhs[0]), tmp, (size_t)n);
    mxFree(tmp);
}

static void do_decompress(const mxArray *prhs[], mxArray *plhs[])
{
    const uint8_t *in = (const uint8_t *)mxGetData(prhs[1]);
    size_t inLen = mxGetNumberOfElements(prhs[1]);
    size_t nbytes, cbytes, blocksize;
    if (inLen < BLOSC_MIN_HEADER_LENGTH)
        mexErrMsgIdAndTxt("zarr:CodecError", "blosc: chunk shorter than header");
    blosc_cbuffer_sizes(in, &nbytes, &cbytes, &blocksize);
    if (cbytes != inLen)
        mexErrMsgIdAndTxt("zarr:CodecError",
                          "blosc: header size %zu != chunk size %zu", cbytes, inLen);
    plhs[0] = mxCreateNumericMatrix(1, (mwSize)nbytes, mxUINT8_CLASS, mxREAL);
    int n = blosc_decompress_ctx(in, mxGetData(plhs[0]), nbytes, 1 /* threads */);
    if (n < 0 || (size_t)n != nbytes)
        mexErrMsgIdAndTxt("zarr:CodecError", "blosc: decompression failed (%d)", n);
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    char mode[16];
    (void)nlhs;
    if (nrhs < 2 || mxGetString(prhs[0], mode, sizeof(mode)) != 0)
        mexErrMsgIdAndTxt("zarr:CodecError", "usage: blosc_mex(mode, bytes, ...)");
    if (!mxIsUint8(prhs[1]))
        mexErrMsgIdAndTxt("zarr:CodecError", "blosc_mex: bytes must be uint8");
    if (strcmp(mode, "compress") == 0) {
        if (nrhs < 6)
            mexErrMsgIdAndTxt("zarr:CodecError",
                              "blosc_mex('compress', bytes, cname, clevel, shuffle, typesize)");
        do_compress(prhs, plhs);
    } else if (strcmp(mode, "decompress") == 0) {
        do_decompress(prhs, plhs);
    } else {
        mexErrMsgIdAndTxt("zarr:CodecError", "blosc_mex: unknown mode '%s'", mode);
    }
}
