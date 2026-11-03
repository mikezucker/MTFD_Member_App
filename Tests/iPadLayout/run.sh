#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT
# Compile the exact production Layout on the host, where SwiftUI's actual layout
# engine can measure portrait, landscape, Split View and accessibility variants.
python3 - "$task_tmp/Grid.swift" <<'PY'
from pathlib import Path
import sys
source = Path('App/AppScreen.swift').read_text()
start = source.index('struct DashboardCardGrid: Layout {')
end = source.index('\nstruct AppScreen<', start)
Path(sys.argv[1]).write_text('import SwiftUI\n' + source[start:end])
PY
xcrun swiftc -parse-as-library "$task_tmp/Grid.swift" Tests/iPadLayout/LayoutTests.swift -o "$task_tmp/layout-tests"
"$task_tmp/layout-tests"
