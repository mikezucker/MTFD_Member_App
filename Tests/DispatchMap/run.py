from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[2]
s=(root/'Features/Dispatch/Views/DashboardDispatchPreviewCard.swift').read_text()
# Compile the production resolver and validation helpers unchanged with fixture lookups.
s=s[:s.index('struct DashboardDispatchPreviewCard:')].replace('import SwiftUI\n','').replace('import UIKit\n','')
with tempfile.TemporaryDirectory(prefix='mtfd-incident-map-') as directory:
 p=Path(directory);(p/'Resolver.swift').write_text(s)
 subprocess.run(['swiftc','-parse-as-library',str(p/'Resolver.swift'),str(root/'Tests/DispatchMap/LocationTests.swift'),'-o',str(p/'tests')],check=True)
 subprocess.run([str(p/'tests')],check=True)
