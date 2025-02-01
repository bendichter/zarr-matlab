import numpy as np
import numcodecs
from pathlib import Path

# Create test data directory if needed
data_dir = Path(__file__).parent / 'data/delta'
data_dir.mkdir(parents=True, exist_ok=True)

# Create and configure codec
codec = numcodecs.Delta(dtype='i4')

# Generate test data
original = np.array([100, 150, 175, 200, 225], dtype='int32')
encoded = codec.encode(original)

# Save encoded data to file
with open(data_dir / 'test_data.bin', 'wb') as f:
    f.write(encoded.tobytes())

print(f"Successfully wrote test data to {data_dir/'test_data.bin'}")
