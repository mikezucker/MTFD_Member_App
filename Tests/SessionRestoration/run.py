"""Exercise production SessionManager with isolated credentials and controlled network replies."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
source = (root / 'Core/Session/SessionManager.swift').read_text()
source = source.replace('import SwiftUI\n', '').replace('import UIKit\n', '')
with tempfile.TemporaryDirectory(prefix='mtfd-restoration-test-') as directory:
    directory = Path(directory)
    production = directory / 'SessionManager.swift'
    production.write_text(source)
    executable = directory / 'tests'
    subprocess.run(['swiftc', '-parse-as-library', str(production),
                    str(root / 'Tests/SessionRestoration/SessionRestorationTests.swift'),
                    '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
