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
    char comp_buf[32] = "zstd";  // default compressor
    int clevel = 5;              // default compression level
    int shuffle = BLOSC_SHUFFLE; // default shuffle
    int blocksize = 0;           // default blocksize (auto)
    
    if (nrhs >= 2) {
        if (!mxIsChar(prhs[1])) {
            mexErrMsgIdAndTxt("Zarr:BloscCompress:InvalidInput",
                "Compressor must be a string");
        }
        mxGetString(prhs[1], comp_buf, sizeof(comp_buf));
    }
    
    // Validate compressor
    if (blosc_set_compressor(comp_buf) < 0) {
        mexErrMsgIdAndTxt("Zarr:BloscCompress:InvalidCompressor",
            "Invalid or unsupported compressor specified");
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
    
    // Allocate output buffer (compressed size is always <= input size + BLOSC_MAX_OVERHEAD)
    size_t max_size = data_size + BLOSC_MAX_OVERHEAD;
    plhs[0] = mxCreateNumericMatrix(1, max_size, mxUINT8_CLASS, mxREAL);
    uint8_t* compressed = (uint8_t*)mxGetData(plhs[0]);
    
    // Set blocksize
    blosc_set_blocksize(blocksize);
    
    // Use BITSHUFFLE for better compression of small integers
    int shuffle_flag = BLOSC_BITSHUFFLE;
    
    // Compress data using blosc_compress_ctx for better control and parallel compression
    int nthreads = blosc_get_nthreads();
    int compressed_size = blosc_compress_ctx(clevel, shuffle_flag, sizeof(uint8_t), data_size,
        data, compressed, max_size, comp_buf, 0, nthreads);
    
    if (compressed_size <= 0) {
        mxDestroyArray(plhs[0]);
        char err_msg[128];
        snprintf(err_msg, sizeof(err_msg), "Blosc compression failed with error code: %d", compressed_size);
        mexErrMsgIdAndTxt("Zarr:BloscCompress:CompressionFailed", err_msg);
    }
    
    // Resize output to actual compressed size
    mxSetN(plhs[0], compressed_size);
}
