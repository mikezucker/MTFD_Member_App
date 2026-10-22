"""Exercise production haptic players with recorded device feedback."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
phone = (root / 'Core/Haptics/HapticsManager.swift').read_text()
phone = phone[phone.index('@MainActor\nfinal class HapticAlertManager'):]
watch = (root / 'MTFD Watch App Watch App/ContentView.swift').read_text()
watch = watch[watch.index('@MainActor\nprivate final class WatchDispatchHaptics'):watch.index('private final class WatchPhoneNavigationBridge')]
watch = watch.replace('private final class WatchDispatchHaptics', 'final class WatchDispatchHaptics').replace('UserDefaults.standard', 'watchTestDefaults')
with tempfile.TemporaryDirectory(prefix='mtfd-haptics-') as directory:
    directory = Path(directory)
    production = directory / 'Players.swift'
    production.write_text('import Foundation\n' + phone + '\n' + watch)
    executable = directory / 'tests'
    subprocess.run(['swiftc', '-parse-as-library', str(production),
                    str(root / 'Tests/DispatchHaptics/PlaybackTests.swift'), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
