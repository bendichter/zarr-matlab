"""M5 interop: zip store + consolidated metadata, python side.

Usage: m5_python.py write   -> scratch/m5_py.zip, scratch/m5_py_cons
       m5_python.py verify  -> checks scratch/m5_ml.zip, scratch/m5_ml_cons
"""
import pathlib
import shutil
import sys

import numpy as np
import zarr

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from interop_cases import pattern


def write():
    p = pathlib.Path("scratch/m5_py.zip")
    p.unlink(missing_ok=True)
    zs = zarr.storage.ZipStore(str(p), mode="w")
    g = zarr.create_group(zs, attributes={"kind": "zipped"})
    a = g.create_array("data", shape=(6, 8), dtype="float64", chunks=(3, 4),
                       compressors=(zarr.codecs.ZstdCodec(level=3),))
    a[...] = pattern((6, 8), "float64")
    s = g.create_array("labels", shape=(4,), dtype="string", chunks=(2,), compressors=())
    s[:] = ["alpha", "beta", "", "delta"]
    zs.close()

    root = pathlib.Path("scratch/m5_py_cons")
    shutil.rmtree(root, ignore_errors=True)
    store = zarr.storage.LocalStore(str(root))
    g = zarr.create_group(store, attributes={"title": "consolidated"})
    g.create_array("x", shape=(4, 4), dtype="float64", chunks=(2, 2))[...] = \
        pattern((4, 4), "float64")
    sub = g.create_group("sub")
    sub.create_array("y", shape=(3, 3), dtype="int32", chunks=(3, 3),
                     compressors=())[...] = pattern((3, 3), "int32")
    zarr.consolidate_metadata(store)
    print("python wrote m5 fixtures")


def verify():
    zs = zarr.storage.ZipStore("scratch/m5_ml.zip", mode="r")
    g = zarr.open_group(zs, mode="r")
    assert g.attrs["kind"] == "zipped"
    np.testing.assert_array_equal(g["data"][...], pattern((6, 8), "float64"))
    assert list(g["labels"][:]) == ["alpha", "beta", "", "delta"]
    zs.close()

    g = zarr.open_consolidated("scratch/m5_ml_cons")
    assert g.metadata.consolidated_metadata is not None, "consolidated missing"
    assert g.attrs["title"] == "consolidated"
    np.testing.assert_array_equal(g["x"][...], np.asarray(magic4(), dtype="float64"))
    np.testing.assert_array_equal(g["sub"]["y"][...], pattern((3, 3), "int32"))
    print("python verified m5 fixtures")


def magic4():
    return [[16, 2, 3, 13], [5, 11, 10, 8], [9, 7, 6, 12], [4, 14, 15, 1]]


if __name__ == "__main__":
    write() if sys.argv[1] == "write" else verify()
