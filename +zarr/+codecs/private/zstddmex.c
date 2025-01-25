#include "mex.h"
#include "matrix.h"
#include "zstd.h"

/* MEX entry point for zstd decompression */
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    /* Check inputs */
    if (nrhs != 1) {
        mexErrMsgIdAndTxt("zarr:zstd:invalidInput",
            "Usage: output = zstddmex(input)");
    }
    
    /* Get input data */
    const uint8_t *input = (uint8_t *)mxGetData(prhs[0]);
    size_t input_size = mxGetNumberOfElements(prhs[0]);
    
    /* Get decompressed size */
    unsigned long long dest_size = ZSTD_getFrameContentSize(input, input_size);
    if (dest_size == ZSTD_CONTENTSIZE_UNKNOWN || dest_size == ZSTD_CONTENTSIZE_ERROR) {
        mexErrMsgIdAndTxt("zarr:zstd:error", "Invalid compressed data");
    }
    
    /* Allocate output buffer */
    plhs[0] = mxCreateNumericMatrix(1, dest_size, mxUINT8_CLASS, mxREAL);
    uint8_t *output = (uint8_t *)mxGetData(plhs[0]);
    
    /* Perform decompression */
    size_t decompressed_size = ZSTD_decompress(output, dest_size, input, input_size);
    if (ZSTD_isError(decompressed_size)) {
        mexErrMsgIdAndTxt("zarr:zstd:error", "Decompression failed");
    }
    
    /* Verify size */
    if (decompressed_size != dest_size) {
        mexErrMsgIdAndTxt("zarr:zstd:error", 
            "Decompression size mismatch: expected %llu, got %zu", 
            dest_size, decompressed_size);
    }
}
