"""Exercise production schedule refresh ownership and failure preservation."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[2]
source = (root / 'Features/Schedule/ViewModels/ScheduleViewModel.swift').read_text().replace('import Combine\n', '')
with tempfile.TemporaryDirectory(prefix='mtfd-schedule-refresh-') as directory:
    directory = Path(directory)
    production = directory / 'ScheduleViewModel.swift'
    production.write_text(source)
    executable = directory / 'tests'
    subprocess.run(['swiftc', '-parse-as-library', str(production),
                    str(root / 'Tests/ScheduleRefresh/ScheduleRefreshTests.swift'), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
