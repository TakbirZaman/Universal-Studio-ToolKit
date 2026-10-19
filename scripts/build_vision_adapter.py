"""Build the pinned, pixel-only OpenCV adapter from explicitly supplied source.

Development only. No source downloads; optional acceleration/codecs/UI/models are
not enabled. The resulting library is not staged in an application automatically.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def build(args):
    root = Path(__file__).resolve().parents[1]
    policy = json.loads((root / 'native/opencv/SOURCE.json').read_text())
    source, work, install = args.source.resolve(), args.work.resolve(), args.install.resolve()
    version = (source / 'modules/core/include/opencv2/core/version.hpp').read_text()
    for suffix, expected in [('MAJOR', 5), ('MINOR', 0), ('REVISION', 0)]:
        if not re.search(r'#define\s+CV_VERSION_' + suffix + r'\s+' + str(expected) + r'\b', version):
            raise ValueError('Supply the pinned OpenCV5.0.0 source; verify its archive against SOURCE.json first.')
    if not (source / 'LICENSE').read_text().lstrip().startswith('Apache License'):
        raise ValueError('The required upstream Apache license is missing.')
    options = sorted(set(re.findall(r'OCV_OPTION\((WITH_[A-Z0-9_]+)', (source / 'CMakeLists.txt').read_text())))
    common = ['-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_POSITION_INDEPENDENT_CODE=ON']
    if args.platform == 'windows-x64':
        generator = ['-G', 'Visual Studio 17 2022', '-A', 'x64']
        common += ['-DBUILD_WITH_STATIC_CRT=OFF', '-DCPU_BASELINE=SSE2']
    else:
        if not args.ninja:
            raise ValueError('Supply the Ninja executable for this platform.')
        generator = ['-G', 'Ninja', '-DCMAKE_MAKE_PROGRAM=' + str(args.ninja.resolve())]
        common += ['-DCMAKE_CXX_FLAGS=-ffunction-sections -fdata-sections']
        if args.platform == 'android-arm64':
            if not args.toolchain:
                raise ValueError('Supply the verified Android NDK CMake toolchain.')
            common += ['-DCMAKE_TOOLCHAIN_FILE=' + str(args.toolchain.resolve()), '-DANDROID_ABI=arm64-v8a',
                       '-DANDROID_PLATFORM=android-24', '-DANDROID_STL=c++_static', '-DCPU_BASELINE=NEON']
        else:
            common += ['-DCPU_BASELINE=SSE2']
    opencv_work, adapter_work = work / 'opencv', work / 'adapter'
    configure = [str(args.cmake), '-S', str(source), '-B', str(opencv_work)] + generator + common + [
        '-DCMAKE_INSTALL_PREFIX=' + str(install), '-DBUILD_LIST=core,imgproc', '-DBUILD_SHARED_LIBS=OFF',
        '-DBUILD_TESTS=OFF', '-DBUILD_PERF_TESTS=OFF', '-DBUILD_EXAMPLES=OFF', '-DBUILD_DOCS=OFF',
        '-DBUILD_opencv_apps=OFF', '-DBUILD_opencv_python2=OFF', '-DBUILD_opencv_python3=OFF',
        '-DBUILD_JAVA=OFF', '-DBUILD_opencv_java=OFF', '-DBUILD_opencv_js=OFF', '-DBUILD_PROTOBUF=OFF',
        '-DBUILD_ANDROID_PROJECTS=OFF', '-DBUILD_ANDROID_EXAMPLES=OFF', '-DBUILD_ANDROID_SERVICE=OFF',
        '-DINSTALL_ANDROID_EXAMPLES=OFF',
        '-DBUILD_TBB=OFF', '-DBUILD_ITT=OFF', '-DBUILD_IPP_IW=OFF', '-DBUILD_ZLIB=ON',
        '-DOPENCV_DISABLE_THREAD_SUPPORT=ON', '-DHAVE_PTHREAD=OFF',
        '-DOPENCV_ENABLE_NONFREE=OFF', '-DOPENCV_GENERATE_PKGCONFIG=OFF', '-DCPU_DISPATCH='] + [
        '-D' + name + '=OFF' for name in options]
    subprocess.run(configure, check=True)
    subprocess.run([str(args.cmake), '--build', str(opencv_work), '--config', 'Release', '--parallel', str(args.jobs)], check=True)
    subprocess.run([str(args.cmake), '--install', str(opencv_work), '--config', 'Release'], check=True)
    configs = list(install.rglob('OpenCVConfig.cmake'))
    if not configs:
        raise ValueError('OpenCV CMake package is missing from the private SDK.')
    configs.sort(key=lambda path: (len(path.parts), str(path)))
    subprocess.run([str(args.cmake), '-S', str(root / 'native/opencv'), '-B', str(adapter_work)] + generator + common +
                   ['-DOpenCV_STATIC=ON', '-DOpenCV_DIR=' + str(configs[0].parent)], check=True)
    subprocess.run([str(args.cmake), '--build', str(adapter_work), '--config', 'Release', '--parallel', str(args.jobs)], check=True)
    filename = 'ust_cv.dll' if args.platform == 'windows-x64' else 'libust_cv.so'
    libraries = list(adapter_work.rglob(filename))
    if len(libraries) != 1:
        raise ValueError('Expected one compiled pixel adapter.')
    library = libraries[0]
    return {'platform': args.platform, 'opencv': policy['version'], 'opencv_source_commit': policy['commit'],
            'library': str(library), 'bytes': library.stat().st_size,
            'sha256': hashlib.file_digest(library.open('rb'), 'sha256').hexdigest(),
            'application_staging_complete': False, 'platform_runtime_verified': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--install', type=Path, required=True)
    parser.add_argument('--cmake', type=Path, required=True)
    parser.add_argument('--ninja', type=Path)
    parser.add_argument('--toolchain', type=Path)
    parser.add_argument('--platform', choices=['linux-x64', 'windows-x64', 'android-arm64'], required=True)
    parser.add_argument('--jobs', type=int, default=4)
    args = parser.parse_args()
    if args.jobs < 1 or args.jobs > 16:
        parser.error('Use 1–16 build workers.')
    print(json.dumps(build(args), indent=2))
