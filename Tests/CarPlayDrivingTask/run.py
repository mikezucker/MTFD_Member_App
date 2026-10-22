"""Exercise production CarPlay detail-stack handling with synchronous interface-controller doubles."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
source = (root / 'CarPlaySceneDelegate.swift').read_text()
a = source.index('    private func openDispatchDetail(')
b = source.index('    // MARK: - Root', a)
method = source[a:b].replace('if #available(iOS 26.4, *)', 'if supportsThreeTemplates')
harness = (root / 'Tests/CarPlayDrivingTask/StackTests.swift').read_text()
with tempfile.TemporaryDirectory(prefix='mtfd-carplay-test-') as directory:
    directory = Path(directory)
    test = directory / 'StackTests.swift'
    test.write_text(harness.replace('// PRODUCTION_DETAIL_METHOD', method))
    executable = directory / 'tests'
    subprocess.run(['swiftc', '-parse-as-library', str(test), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
