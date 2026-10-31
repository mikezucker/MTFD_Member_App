from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[2]
s=(root/'Features/Dashboard/ViewModels/DashboardViewModel.swift').read_text()
start=s.index('    private func fetchPendingPolicyDocuments()');end=s.index('    private func mapBulletins',start)
method=s[start:end].replace('private func','func',1)
fixture="""import Foundation
struct DashboardPendingPolicy {let id:String;let title:String;let category:String;let folderName:String?}
struct Version {let requiresAcknowledgement:Bool}
struct Doc {let id:String;let title:String;let category:String;let folderId:String?;let latestVersion:Version?}
struct Folder {let id:String;let name:String}
struct Response {let folders:[Folder];let documents:[Doc]}
final class APIClient {static let shared=APIClient(); var documents:[Doc]=[];var fails=false
func fetchDocuments() async throws -> Response {if fails {throw NSError(domain:"test",code:1)};return Response(folders:[Folder(id:"f",name:"Policies")],documents:documents)}}
struct Subject {
"""+method+"""}
@main struct Tests {static func main() async {
APIClient.shared.documents=(0..<150).map{Doc(id:String($0),title:String(format:"Policy %03d",149-$0),category:"POLICY",folderId:"f",latestVersion:Version(requiresAcknowledgement:true))}
APIClient.shared.documents += [Doc(id:"signed",title:"Signed",category:"POLICY",folderId:nil,latestVersion:Version(requiresAcknowledgement:false)),Doc(id:"empty",title:"Empty",category:"OTHER",folderId:nil,latestVersion:nil)]
let pending=await Subject().fetchPendingPolicyDocuments()
precondition(pending.count==150,"All pending policies must contribute to total")
precondition(pending.first?.title=="Policy 000")
precondition(pending.allSatisfy{$0.folderName=="Policies"})
precondition(Array(pending.prefix(3)).count==3)
APIClient.shared.documents=[]
precondition(awaitCount(await Subject().fetchPendingPolicyDocuments())==0)
APIClient.shared.fails=true
precondition(awaitCount(await Subject().fetchPendingPolicyDocuments())==0)
print("PASS: 150 pending policies counted, signed/missing versions excluded, sorted preview and empty/error handling")
}
}
"""
# Await outside Swift precondition's synchronous autoclosure.
fixture=fixture.replace('precondition(awaitCount(await Subject().fetchPendingPolicyDocuments())==0)','let empty=await Subject().fetchPendingPolicyDocuments();precondition(empty.count==0)',1)
fixture=fixture.replace('precondition(awaitCount(await Subject().fetchPendingPolicyDocuments())==0)','let failed=await Subject().fetchPendingPolicyDocuments();precondition(failed.count==0)',1)
with tempfile.TemporaryDirectory() as d:
 p=Path(d);(p/'test.swift').write_text(fixture)
 subprocess.run(['swiftc','-parse-as-library',str(p/'test.swift'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
