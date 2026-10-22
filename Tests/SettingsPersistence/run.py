from pathlib import Path
import subprocess, tempfile
root = Path(__file__).resolve().parents[2]
source = (root / 'Features/Settings/ViewModels/NotificationPreferencesViewModel.swift').read_text().replace('import Combine\n', '').replace('UserDefaults.standard','settingsTestDefaults')
with tempfile.TemporaryDirectory(prefix='mtfd-settings-') as directory:
    directory=Path(directory)
    production=directory/'ViewModel.swift'
    production.write_text(source)
    executable=directory/'tests'
    subprocess.run(['swiftc','-parse-as-library',str(root/'Features/Settings/Models/NotificationPreferences.swift'),str(production),str(root/'Tests/SettingsPersistence/SaveTests.swift'),'-o',str(executable)],check=True)
    subprocess.run([str(executable)],check=True)
