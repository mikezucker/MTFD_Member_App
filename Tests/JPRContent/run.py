from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='mtfd-jpr-content-') as directory:
    exe=Path(directory)/'test'
    subprocess.run(['swiftc','-parse-as-library',str(root/'Features/Training/Models/MobileTrainingResponse.swift'),str(root/'Features/Training/Models/TrainingWorkspaceModels.swift'),str(root/'Tests/JPRContent/ContentTests.swift'),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
