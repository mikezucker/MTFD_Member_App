from pathlib import Path
import subprocess, tempfile
root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='mtfd-training-home-') as directory:
    executable = Path(directory) / 'tests'
    subprocess.run(['swiftc', '-parse-as-library', str(root / 'Features/Training/Models/MobileTrainingResponse.swift'), str(root / 'Features/Training/Models/TrainingWorkspaceModels.swift'), str(root / 'Tests/TrainingHome/HomeTests.swift'), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
