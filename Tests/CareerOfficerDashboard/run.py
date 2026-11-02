from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[2]
s=(root/'Features/Dashboard/Views/CareerOfficerDashboardView.swift').read_text()
a=s.index('    private var selectedTotalsWindow:');b=s.index('    private var primaryActiveDispatch:',a)
properties=s[a:b].replace('private var','var')
a=s.index('    private enum OfficerTotalsScope:');end=s.index('{',a)+1;depth=1
while depth:
 if s[end]=='{':depth+=1
 if s[end]=='}':depth-=1
 end+=1
enum=s[a:end].replace('private enum','enum')
source='''import Foundation
enum DashboardTotalsWindow: String {case ytd = "YTD"}
enum APIClient {
 struct DispatchBucket: Equatable {let count:Int}
 struct ChiefStationStats {var all:DispatchBucket?;var station1:DispatchBucket?;var station2:DispatchBucket?;var station3:DispatchBucket?;var station4:DispatchBucket?;var station5:DispatchBucket?}
}
'''+enum+'''
struct Subject {
 var selectedWindowRawValue="YTD"
 var selectedTotalsScopeRawValue="1"
 var departmentStats:APIClient.DispatchBucket?=APIClient.DispatchBucket(count:42)
 var chiefStationStats:APIClient.ChiefStationStats?
'''+properties+'''}
@main struct Tests {static func main() {
 var subject=Subject()
 precondition(subject.selectedTotalsScope == .department,"A saved station selection without a station response must fall back to department totals")
 precondition(subject.selectedTotalsBucket?.count == 42)
 precondition(subject.availableTotalsScopes == [.department])
 subject.chiefStationStats=APIClient.ChiefStationStats(all:.init(count:100),station1:.init(count:5),station3:.init(count:9))
 precondition(subject.selectedTotalsScope == .station1 && subject.selectedTotalsBucket?.count == 5)
 precondition(subject.availableTotalsScopes == [.department,.station1,.station3])
 subject.selectedTotalsScopeRawValue="2"
 precondition(subject.selectedTotalsScope == .department && subject.selectedTotalsBucket?.count == 100)
 print("PASS: career officer totals recover from missing station buckets and expose only available scopes")
}}
'''
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder);(p/'tests.swift').write_text(source)
 subprocess.run(['swiftc','-parse-as-library',str(p/'tests.swift'),'-o',str(p/'tests')],check=True)
 subprocess.run([str(p/'tests')],check=True)
