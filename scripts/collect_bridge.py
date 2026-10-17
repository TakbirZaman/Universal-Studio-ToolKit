"""Export only the fixed, public generated source paths for review and commit."""
import json
from pathlib import Path

paths = [
    "lib/src/rust/api.dart",
    "lib/src/rust/jobs.dart",
    "lib/src/rust/ocr.dart",
    "lib/src/rust/frb_generated.dart",
    "lib/src/rust/frb_generated.io.dart",
    "rust/src/frb_generated.rs",
]
Path("dist").mkdir(exist_ok=True)
Path("dist/generated-bridge.json").write_text(
    json.dumps({p: Path(p).read_text() for p in paths}, ensure_ascii=False),
    encoding="utf-8",
)
