import zarr
import numpy as np
from numcodecs import Shuffle

store = zarr.DirectoryStore('tests/data/shuffle_zarr')
root = zarr.group(store=store, overwrite=True)

dtypes = [
    ('int32', 4),
    ('uint16', 2), 
    ('float32', 4),
    ('float64', 8)
]

for dtype, elem_size in dtypes:
    grp = root.create_group(dtype)
    
    # 1D array
    data = np.random.randint(0, 100, size=10).astype(dtype)
    grp.create_dataset('1d', data=data, chunks=5, 
                      compressor=Shuffle(elementsize=elem_size))
    
    # 2D array
    data = np.random.randn(4, 4).astype(dtype)
    grp.create_dataset('2d', data=data, chunks=(2, 2),
                      compressor=Shuffle(elementsize=elem_size))
    
    # 3D array
    data = np.random.randn(2, 3, 4).astype(dtype)
    grp.create_dataset('3d', data=data, chunks=(1, 3, 2),
                      compressor=Shuffle(elementsize=elem_size))
