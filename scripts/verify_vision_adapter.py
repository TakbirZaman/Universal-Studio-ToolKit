"""Independent ctypes/NumPy/Pillow checks for the pixel-only development adapter."""
import argparse
import ctypes as c
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw


def file_sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verify(path):
    library = c.CDLL(str(path.resolve()))
    library.ust_cv_abi_version.restype = c.c_uint32
    library.ust_cv_engine_version.restype = c.c_uint32
    assert library.ust_cv_abi_version() == 1
    assert library.ust_cv_engine_version() == 50000
    pointer = c.POINTER(c.c_uint8)
    double_pointer = c.POINTER(c.c_double)
    warp = library.ust_cv_warp_rgba
    warp.argtypes = [pointer, c.c_uint32, c.c_uint32, c.c_size_t, double_pointer,
                     c.c_size_t, pointer, c.c_uint32, c.c_uint32, c.c_size_t]
    warp.restype = c.c_int32
    suggest = library.ust_cv_suggest_rgba
    suggest.argtypes = [pointer, c.c_uint32, c.c_uint32, c.c_size_t, double_pointer, c.c_size_t]
    suggest.restype = c.c_int32
    height, width = 184, 272
    source = np.zeros((height, width, 4), dtype=np.uint8)
    source[:, :, 0] = np.rint(np.arange(width) * 255 / (width-1)).astype(np.uint8)
    source[:, :, 1] = np.rint(np.arange(height)[:, None] * 255 / (height-1)).astype(np.uint8)
    source[:, :, 2] = 80
    source[:, :, 3] = 255
    original = source.copy()
    full = np.array([0,0,1,0,1,1,0,1], dtype=np.float64)

    def run(corners, output):
        return warp(source.ctypes.data_as(pointer), width, height, source.nbytes,
                    corners.ctypes.data_as(double_pointer), corners.size,
                    output.ctypes.data_as(pointer), output.shape[1], output.shape[0], output.nbytes)

    identity = np.zeros_like(source)
    assert run(full, identity) == 0 and np.array_equal(identity, source)
    corners = np.array([.12,.18,.82,.10,.90,.82,.08,.90], dtype=np.float64)
    output = np.zeros((220,160,4), dtype=np.uint8)
    assert run(corners, output) == 0 and np.all(output[:, :, 3] == 255)
    # Solve destination->source homography independently, then test sampled
    # output coordinates against the known source colour gradients.
    src = corners.reshape((4,2))*np.array([width-1,height-1])
    dst = [(0,0),(159,0),(159,219),(0,219)]
    matrix, values = [], []
    for (x,y),(u,v) in zip(dst,src):
        matrix.extend([[x,y,1,0,0,0,-u*x,-u*y], [0,0,0,x,y,1,-v*x,-v*y]])
        values.extend([u,v])
    transform = np.append(np.linalg.solve(np.array(matrix),np.array(values)),1).reshape((3,3))
    errors = []
    for x,y in [(0,0),(159,0),(159,219),(0,219),(79,109),(40,55),(120,170)]:
        position = transform @ [x,y,1]
        position = position[:2]/position[2]
        expected = position * np.array([255/(width-1),255/(height-1)])
        errors.append(float(np.max(np.abs(output[y,x,:2].astype(float)-expected))))
    assert max(errors) <= 2
    assert np.array_equal(source, original)
    sentinel = np.full_like(source, 123)
    for invalid in [np.array([0,0,1,1,1,0,0,1],dtype=np.float64),
                    np.array([float('nan'),0,1,0,1,1,0,1]),
                    np.array([-.1,0,1,0,1,1,0,1]),
                    np.array([0,0,.001,0,.001,.001,0,.001])]:
        assert run(invalid, sentinel) == 2 and np.all(sentinel == 123)
    assert warp(None,width,height,source.nbytes,full.ctypes.data_as(double_pointer),8,
                sentinel.ctypes.data_as(pointer),width,height,sentinel.nbytes) == 2
    assert warp(source.ctypes.data_as(pointer),width,height,source.nbytes-1,full.ctypes.data_as(double_pointer),8,
                sentinel.ctypes.data_as(pointer),width,height,sentinel.nbytes) == 2
    blank = np.full_like(source,255)
    found = np.full(8,99,dtype=np.float64)
    assert suggest(blank.ctypes.data_as(pointer),width,height,blank.nbytes,
                   found.ctypes.data_as(double_pointer),8) == 1
    assert np.all(found == 99)
    image = Image.new('RGBA',(width,height),(25,25,25,255))
    rectangle = [(30,25),(240,20),(250,160),(20,165)]
    ImageDraw.Draw(image).polygon(rectangle,fill=(245,245,245,255))
    page = np.array(image)
    assert suggest(page.ctypes.data_as(pointer),width,height,page.nbytes,
                   found.ctypes.data_as(double_pointer),8) == 0
    expected = np.array(rectangle)/np.array([width-1,height-1])
    assert np.max(np.abs(found.reshape((4,2))-expected)) < .025
    return {'abi':1,'opencv_version':50000,'identity_exact_pixels':True,
            'perspective_max_gradient_error':max(errors),'source_unchanged':True,
            'invalid_inputs_leave_output_unchanged':True,'blank_has_no_suggestion':True,
            'synthetic_quad_suggestion_verified':True,'sample_images_uploaded':False,
            'library_sha256':file_sha256(path),
            'windows_android_verified':False,'application_integration_complete':False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--library',type=Path,required=True)
    print(json.dumps(verify(parser.parse_args().library),indent=2))
