#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT
python3 - "$task_tmp/Export.swift" <<'PY'
from pathlib import Path
import sys
source = Path('Features/Training/Views/TrainingWorkspaceView.swift').read_text()
start = source.index('@MainActor private final class JPRVideoExport {')
end = source.index('\nprivate struct JPRStepMediaEditor:', start)
Path(sys.argv[1]).write_text('import Foundation\nimport AVFoundation\n' + source[start:end] + '\n' + Path('Tests/JPRMediaExport/ExportTests.swift').read_text())
PY
xcrun swiftc -parse-as-library -swift-version 6 "$task_tmp/Export.swift" -o "$task_tmp/export-tests"
"$task_tmp/export-tests"
