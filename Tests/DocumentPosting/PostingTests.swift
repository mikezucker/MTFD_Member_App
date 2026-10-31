import Foundation
struct Fixture: Decodable { let options: APIClient.DocumentPostOptions; let receipt: APIClient.DocumentPostReceipt }
@main struct PostingTests {
 static func main() throws {
  let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
  let fixture = try JSONDecoder().decode(Fixture.self, from: data)
  precondition(fixture.options.success)
  precondition(!fixture.options.canPostDepartment)
  precondition(fixture.options.scopeLabel == "Your company only")
  precondition(fixture.options.users.allSatisfy { $0.company == "MT_KEMBLE" })
  precondition(fixture.receipt.success && fixture.receipt.recipientCount == 1)
  precondition(!fixture.receipt.documentId.isEmpty)
  let changed = String(data: data, encoding: .utf8)!.replacingOccurrences(of: "Your company only", with: "Department review")
  let changedFixture = try JSONDecoder().decode(Fixture.self, from: Data(changed.utf8))
  precondition(changedFixture.options.scopeLabel == "Department review")
  print("PASS: actual posting API contract, scoped recipients, receipt and dynamic scope labels")
 }
}
