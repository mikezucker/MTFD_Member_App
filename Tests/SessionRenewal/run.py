"""Compile and exercise the production renewal actor using isolated in-memory credentials.
Runs on macOS with Xcode; never contacts MTFD or writes to the real Keychain.
"""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[2]
api = (root / 'Services/Network/APIClient.swift').read_text()
key = (root / 'Services/Auth/KeychainService.swift').read_text()
credentials = key[key.index('struct MobileSessionCredentials:'):key.index('extension KeychainService {')]
actor = api[api.index('actor MobileSessionRenewal {'):]
with tempfile.TemporaryDirectory(prefix='mtfd-renewal-test-') as directory:
    directory = Path(directory)
    source = directory / 'Renewal.swift'
    source.write_text('import Foundation\n' + credentials + '\n' + actor)
    executable = directory / 'tests'
    subprocess.run(['swiftc', '-parse-as-library', str(source), str(root / 'Tests/SessionRenewal/SessionRenewalTests.swift'), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
