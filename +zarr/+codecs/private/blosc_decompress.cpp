#include "mex.h"
#include "blosc.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // Check inputs
    if (nrhs != 1) {
        mexErrMsgIdAndTxt("Zarr:BloscDecompress:InvalidInput",
            "Usage: decompressed = blosc_decompress(compressed_data)");
    }
    
    // Get input data
    if (!mxIsUint8(prhs[0])) {
        mexErrMsgIdAndTxt("Zarr:BloscDecompress:InvalidInput",
            "Input data must be uint8");
    }
    const uint8_t* compressed = (uint8_t*)mxGetData(prhs[0]);
    size_t compressed_size = mxGetNumberOfElements(prhs[0]);
    
    // Initialize Blosc if needed
    static bool blosc_initialized = false;
    if (!blosc_initialized) {
        blosc_init();
        blosc_initialized = true;
    }
    
    // Get decompressed size
    size_t nbytes, cbytes, blocksize;
    int typesize;
    if (blosc_cbuffer_sizes(compressed, &nbytes, &cbytes, &blocksize) < 0) {
        mexErrMsgIdAndTxt("Zarr:BloscDecompress:InvalidData",
            "Invalid Blosc compressed data");
    }
    
    // Allocate output buffer
    plhs[0] = mxCreateNumericMatrix(1, nbytes, mxUINT8_CLASS, mxREAL);
    uint8_t* decompressed = (uint8_t*)mxGetData(plhs[0]);
    
    // Decompress data
    int decompressed_size = blosc_decompress(compressed, decompressed, nbytes);
    
    if (decompressed_size < 0) {
        mxDestroyArray(plhs[0]);
        mexErrMsgIdAndTxt("Zarr:BloscDecompress:DecompressionFailed",
            "Blosc decompression failed");
    }
    
    if (decompressed_size != nbytes) {
        mxDestroyArray(plhs[0]);
        mexErrMsgIdAndTxt("Zarr:BloscDecompress:SizeMismatch",
            "Decompressed size does not match expected size");
    }
}
