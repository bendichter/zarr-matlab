import numpy as np
import numcodecs
from pathlib import Path
import tempfile
import os

# Use system temp directory
temp_dir = Path(tempfile.gettempdir()) / 'zarr_matlab_test_data'
temp_dir.mkdir(parents=True, exist_ok=True)

# Create and configure codec
codec = numcodecs.Delta(dtype='i4')

# Generate test data
original = np.array([100, 150, 175, 200, 225], dtype='int32')
encoded = codec.encode(original)

# Save encoded data to temp file
test_file = temp_dir / 'delta_test_data.bin'
with open(test_file, 'wb') as f:
    f.write(encoded.tobytes())

# Print the path for MATLAB test to use
print(f"MATLAB_TEST_FILE={test_file}")
