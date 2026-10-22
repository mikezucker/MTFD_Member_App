from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[2]
source = (root / 'Features/Dispatch/Models/DispatchNotificationPayload.swift').read_text().replace('import Combine\n', '')
with tempfile.TemporaryDirectory(prefix='mtfd-dispatch-attention-') as directory:
    directory = Path(directory)
    production = directory / 'Payload.swift'
    production.write_text(source)
    binary = directory / 'tests'
    subprocess.run(['swiftc', '-parse-as-library', str(production), str(root / 'Tests/DispatchAttention/QueueTests.swift'), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
