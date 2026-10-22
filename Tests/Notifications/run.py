from pathlib import Path
import subprocess, tempfile
root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="mtfd-notification-test-") as directory:
    executable = str(Path(directory) / "tests")
    sources = ["Features/Settings/Models/NotificationPreferences.swift", "Features/Dispatch/Models/DispatchNotificationPayload.swift", "Core/Notifications/NotificationEngine.swift", "Core/Navigation/NavigationRouter.swift", "Tests/Notifications/PolicyTests.swift"]
    subprocess.run(["swiftc", "-parse-as-library", *[str(root / p) for p in sources], "-o", executable], check=True)
    subprocess.run([executable], check=True)
