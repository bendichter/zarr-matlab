#include "mex.h"
#include "blosc.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // Check inputs
    if (nrhs < 1 || nrhs > 5) {
        mexErrMsgIdAndTxt("Zarr:BloscCompress:InvalidInput",
            "Usage: compressed = blosc_compress(data, compressor, level, shuffle, blocksize)");
    }
    
    // Get input data
    if (!mxIsUint8(prhs[0])) {
        mexErrMsgIdAndTxt("Zarr:BloscCompress:InvalidInput",
            "Input data must be uint8");
    }
    const uint8_t* data = (uint8_t*)mxGetData(prhs[0]);
    size_t data_size = mxGetNumberOfElements(prhs[0]);
    
    // Get optional parameters
    const char* compressor = "zstd";  // default compressor
    int clevel = 5;                   // default compression level
    int shuffle = BLOSC_SHUFFLE;      // default shuffle
    int blocksize = 0;                // default blocksize (auto)
    
    if (nrhs >= 2) {
        if (!mxIsChar(prhs[1])) {
            mexErrMsgIdAndTxt("Zarr:BloscCompress:InvalidInput",
                "Compressor must be a string");
        }
        char comp_buf[32];
        mxGetString(prhs[1], comp_buf, sizeof(comp_buf));
        compressor = comp_buf;
    }
    
    if (nrhs >= 3) {
        if (!mxIsNumeric(prhs[2])) {
            mexErrMsgIdAndTxt("Zarr:BloscCompress:InvalidInput",
                "Compression level must be numeric");
        }
        clevel = (int)mxGetScalar(prhs[2]);
        if (clevel < 1 || clevel > 9) {
            mexErrMsgIdAndTxt("Zarr:BloscCompress:InvalidInput",
                "Compression level must be between 1 and 9");
        }
    }
    
    if (nrhs >= 4) {
        if (!mxIsLogical(prhs[3])) {
            mexErrMsgIdAndTxt("Zarr:BloscCompress:InvalidInput",
                "Shuffle must be logical");
        }
        shuffle = mxIsLogicalScalarTrue(prhs[3]) ? BLOSC_SHUFFLE : BLOSC_NOSHUFFLE;
    }
    
    if (nrhs >= 5) {
        if (!mxIsNumeric(prhs[4])) {
            mexErrMsgIdAndTxt("Zarr:BloscCompress:InvalidInput",
                "Blocksize must be numeric");
        }
        blocksize = (int)mxGetScalar(prhs[4]);
        if (blocksize < 0) {
            mexErrMsgIdAndTxt("Zarr:BloscCompress:InvalidInput",
                "Blocksize must be non-negative");
        }
    }
    
    // Initialize Blosc if needed
    static bool blosc_initialized = false;
    if (!blosc_initialized) {
        blosc_init();
        blosc_initialized = true;
    }
    
    // Set compressor
    if (blosc_set_compressor(compressor) < 0) {
        mexErrMsgIdAndTxt("Zarr:BloscCompress:InvalidCompressor",
            "Invalid compressor specified");
    }
    
    // Allocate output buffer (compressed size is always <= input size + BLOSC_MAX_OVERHEAD)
    size_t max_size = data_size + BLOSC_MAX_OVERHEAD;
    plhs[0] = mxCreateNumericMatrix(1, max_size, mxUINT8_CLASS, mxREAL);
    uint8_t* compressed = (uint8_t*)mxGetData(plhs[0]);
    
    // Compress data
    int compressed_size = blosc_compress(clevel, shuffle, sizeof(uint8_t), data_size, 
        data, compressed, max_size);
    
    if (compressed_size < 0) {
        mxDestroyArray(plhs[0]);
        mexErrMsgIdAndTxt("Zarr:BloscCompress:CompressionFailed",
            "Blosc compression failed");
    }
    
    // Resize output to actual compressed size
    mxSetN(plhs[0], compressed_size);
}
