from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[2]
live=(root/'Core/LiveActivities/DispatchLiveActivityManager.swift').read_text()
live=live[live.index('struct DispatchLiveActivitySettings'):live.index('@MainActor\nfinal class DispatchLiveActivityManager')]
layout=(root/'Features/Dashboard/Models/DashboardCardLayout.swift').read_text().replace('UserDefaults = .standard','UserDefaults = behaviorTestDefaults')
with tempfile.TemporaryDirectory(prefix='mtfd-settings-behavior-') as directory:
    directory=Path(directory)
    source=directory/'Policies.swift'
    source.write_text('import Foundation\n'+live+'\n'+layout)
    executable=directory/'tests'
    subprocess.run(['swiftc','-parse-as-library',str(source),str(root/'Tests/SettingsBehavior/BehaviorTests.swift'),'-o',str(executable)],check=True)
    subprocess.run([str(executable)],check=True)
