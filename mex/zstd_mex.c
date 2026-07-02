/* zstd_mex.c - Zstandard codec for zarr-matlab.
 *
 *   out = zstd_mex('compress',   uint8vec, level, checksum)
 *   out = zstd_mex('decompress', uint8vec)
 */
#include <string.h>
#include <zstd.h>
#include "mex.h"

static void do_compress(int nrhs, const mxArray *prhs[], mxArray *plhs[])
{
    const uint8_t *in = (const uint8_t *)mxGetData(prhs[1]);
    size_t inLen = mxGetNumberOfElements(prhs[1]);
    int level = (nrhs > 2) ? (int)mxGetScalar(prhs[2]) : 0;
    int checksum = (nrhs > 3) ? (int)(mxGetScalar(prhs[3]) != 0) : 0;

    ZSTD_CCtx *cctx = ZSTD_createCCtx();
    if (!cctx) mexErrMsgIdAndTxt("zarr:CodecError", "zstd: cannot create context");
    ZSTD_CCtx_setParameter(cctx, ZSTD_c_compressionLevel, level);
    ZSTD_CCtx_setParameter(cctx, ZSTD_c_checksumFlag, checksum);

    size_t bound = ZSTD_compressBound(inLen);
    uint8_t *tmp = (uint8_t *)mxMalloc(bound);
    size_t n = ZSTD_compress2(cctx, tmp, bound, in, inLen);
    ZSTD_freeCCtx(cctx);
    if (ZSTD_isError(n)) {
        mxFree(tmp);
        mexErrMsgIdAndTxt("zarr:CodecError", "zstd: %s", ZSTD_getErrorName(n));
    }
    plhs[0] = mxCreateNumericMatrix(1, (mwSize)n, mxUINT8_CLASS, mxREAL);
    memcpy(mxGetData(plhs[0]), tmp, n);
    mxFree(tmp);
}

static void do_decompress(const mxArray *prhs[], mxArray *plhs[])
{
    const uint8_t *in = (const uint8_t *)mxGetData(prhs[1]);
    size_t inLen = mxGetNumberOfElements(prhs[1]);

    unsigned long long content = ZSTD_getFrameContentSize(in, inLen);
    if (content == ZSTD_CONTENTSIZE_ERROR)
        mexErrMsgIdAndTxt("zarr:CodecError", "zstd: not a zstd frame");

    if (content != ZSTD_CONTENTSIZE_UNKNOWN) {
        plhs[0] = mxCreateNumericMatrix(1, (mwSize)content, mxUINT8_CLASS, mxREAL);
        size_t n = ZSTD_decompress(mxGetData(plhs[0]), (size_t)content, in, inLen);
        if (ZSTD_isError(n) || n != (size_t)content)
            mexErrMsgIdAndTxt("zarr:CodecError", "zstd: %s",
                              ZSTD_isError(n) ? ZSTD_getErrorName(n) : "size mismatch");
        return;
    }

    /* Streaming fallback for frames without a recorded content size. */
    ZSTD_DCtx *dctx = ZSTD_createDCtx();
    if (!dctx) mexErrMsgIdAndTxt("zarr:CodecError", "zstd: cannot create context");
    size_t cap = inLen * 4 + 4096;
    uint8_t *out = (uint8_t *)mxMalloc(cap);
    ZSTD_inBuffer ib = { in, inLen, 0 };
    ZSTD_outBuffer ob = { out, cap, 0 };
    for (;;) {
        size_t r = ZSTD_decompressStream(dctx, &ob, &ib);
        if (ZSTD_isError(r)) {
            ZSTD_freeDCtx(dctx); mxFree(out);
            mexErrMsgIdAndTxt("zarr:CodecError", "zstd: %s", ZSTD_getErrorName(r));
        }
        if (r == 0 && ib.pos == ib.size) break;
        if (ob.pos == ob.size) {
            cap *= 2;
            out = (uint8_t *)mxRealloc(out, cap);
            ob.dst = out; ob.size = cap;
        } else if (ib.pos == ib.size && r != 0) {
            ZSTD_freeDCtx(dctx); mxFree(out);
            mexErrMsgIdAndTxt("zarr:CodecError", "zstd: truncated frame");
        }
    }
    ZSTD_freeDCtx(dctx);
    plhs[0] = mxCreateNumericMatrix(1, (mwSize)ob.pos, mxUINT8_CLASS, mxREAL);
    memcpy(mxGetData(plhs[0]), out, ob.pos);
    mxFree(out);
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    char mode[16];
    (void)nlhs;
    if (nrhs < 2 || mxGetString(prhs[0], mode, sizeof(mode)) != 0)
        mexErrMsgIdAndTxt("zarr:CodecError", "usage: zstd_mex(mode, bytes, ...)");
    if (!mxIsUint8(prhs[1]))
        mexErrMsgIdAndTxt("zarr:CodecError", "zstd_mex: bytes must be uint8");
    if (strcmp(mode, "compress") == 0)
        do_compress(nrhs, prhs, plhs);
    else if (strcmp(mode, "decompress") == 0)
        do_decompress(prhs, plhs);
    else
        mexErrMsgIdAndTxt("zarr:CodecError", "zstd_mex: unknown mode '%s'", mode);
}
