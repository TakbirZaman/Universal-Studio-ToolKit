# Microsoft Visual C++ runtime (Windows bundle only)

The Windows packaging script copies unmodified release CRT files from the installed Visual Studio 2022 `VC/Redist/MSVC/.../x64/Microsoft.VC143.CRT` directory. Debug runtime files and operating-system libraries are excluded. Microsoft retains its rights in these components; the project's MIT license does not relicense them.

Redistribution basis: the Visual Studio 2022 distributable-code list permits licensed Visual Studio users to distribute the listed unmodified runtime components with their programs, subject to the applicable Visual Studio license terms. The build must use a validly licensed Visual Studio installation. No runtime fee or license-server call is added to the application.

Primary references checked 2026-10-16:
- https://learn.microsoft.com/en-us/visualstudio/releases/2022/redistribution
- https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files
- https://docs.flutter.dev/platform-integration/windows/building

The bundle's `microsoft-runtime-provenance.json` records exact filenames, versions and SHA-256 hashes. Runtime files are not modified. Clean-system compatibility remains a separate test requirement.
