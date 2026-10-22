"""Exercise the production refresh owner with controlled network completion."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
source = (root / 'Features/Training/ViewModels/TrainingViewModel.swift').read_text()
source = source.replace('import SwiftUI\n', '').replace('import Combine\n', '')
source = source.replace('UserDefaults.standard', 'trainingTestDefaults')
with tempfile.TemporaryDirectory(prefix='mtfd-training-refresh-') as directory:
    directory = Path(directory)
    production = directory / 'TrainingViewModel.swift'
    production.write_text(source)
    executable = directory / 'tests'
    subprocess.run(['swiftc', '-parse-as-library', str(production),
                    str(root / 'Tests/TrainingRefresh/TrainingRefreshTests.swift'),
                    '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
