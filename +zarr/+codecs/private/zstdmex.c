#include "mex.h"
#include "matrix.h"
#include "zstd.h"

/* MEX entry point for zstd compression */
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    /* Check inputs */
    if (nrhs < 1 || nrhs > 3) {
        mexErrMsgIdAndTxt("zarr:zstd:invalidInput",
            "Usage: output = zstdmex(input, level, checksum)");
    }
    
    /* Get input data */
    const uint8_t *input = (uint8_t *)mxGetData(prhs[0]);
    size_t input_size = mxGetNumberOfElements(prhs[0]);
    
    /* Get compression level (optional) */
    int level = ZSTD_defaultCLevel();
    if (nrhs >= 2) {
        level = (int)mxGetScalar(prhs[1]);
        if (level > ZSTD_maxCLevel()) {
            level = ZSTD_maxCLevel();
        }
    }
    
    /* Get checksum flag (optional) */
    int checksum = 0;
    if (nrhs >= 3) {
        checksum = (int)mxGetScalar(prhs[2]);
    }
    
    /* Create compression context */
    ZSTD_CCtx* cctx = ZSTD_createCCtx();
    if (!cctx) {
        mexErrMsgIdAndTxt("zarr:zstd:error", "Failed to create compression context");
    }
    
    /* Set compression parameters */
    size_t ret = ZSTD_CCtx_setParameter(cctx, ZSTD_c_compressionLevel, level);
    if (ZSTD_isError(ret)) {
        ZSTD_freeCCtx(cctx);
        mexErrMsgIdAndTxt("zarr:zstd:error", "Failed to set compression level");
    }
    
    ret = ZSTD_CCtx_setParameter(cctx, ZSTD_c_checksumFlag, checksum ? 1 : 0);
    if (ZSTD_isError(ret)) {
        ZSTD_freeCCtx(cctx);
        mexErrMsgIdAndTxt("zarr:zstd:error", "Failed to set checksum flag");
    }
    
    /* Allocate output buffer */
    size_t output_size = ZSTD_compressBound(input_size);
    plhs[0] = mxCreateNumericMatrix(1, output_size, mxUINT8_CLASS, mxREAL);
    uint8_t *output = (uint8_t *)mxGetData(plhs[0]);
    
    /* Perform compression */
    size_t compressed_size = ZSTD_compress2(cctx, output, output_size, input, input_size);
    if (ZSTD_isError(compressed_size)) {
        ZSTD_freeCCtx(cctx);
        mexErrMsgIdAndTxt("zarr:zstd:error", "Compression failed");
    }
    
    /* Cleanup */
    ZSTD_freeCCtx(cctx);
    
    /* Resize output to actual compressed size */
    mxSetN(plhs[0], compressed_size);
}
