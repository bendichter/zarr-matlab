import numpy as np
import numcodecs
from pathlib import Path
import tempfile
import os

# Create data directory in tests folder
data_dir = Path(__file__).parent / 'data' / 'delta'
data_dir.mkdir(parents=True, exist_ok=True)

# Create and configure codec
codec = numcodecs.Delta(dtype='i4')

# Generate test data
original = np.array([100, 150, 175, 200, 225], dtype='int32')
encoded = codec.encode(original)

# Save encoded data
test_file = data_dir / 'test_data.bin'
with open(test_file, 'wb') as f:
    f.write(encoded.tobytes())
