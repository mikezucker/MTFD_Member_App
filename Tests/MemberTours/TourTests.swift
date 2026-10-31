import Foundation
@main struct TourTests {
    struct Fixture: Decodable {let snapshot:AdminTourSnapshot;let member:APIClient.Member;let current:APIClient.CurrentMemberTourResponse}
    static func main() throws {
        let decoder=JSONDecoder();decoder.keyDecodingStrategy = .convertFromSnakeCase
        let data=try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))
        let fixture=try decoder.decode(Fixture.self,from:data)
        assert(fixture.snapshot.tours.contains{$0.name=="Future Watch"},"Tour list must accept additional and renamed tours")
        assert(fixture.snapshot.tours.contains{$0.name=="Blue Watch"})
        assert(fixture.member.tour?.name=="Tour 2")
        assert(fixture.member.tour?.lieutenant?.name=="Synthetic Lieutenant Two")
        assert(fixture.current.tour?.id==fixture.member.tour?.id)
        let legacy=try decoder.decode(APIClient.Member.self,from:Data(#"{"name":"Legacy member","role":"MEMBER_CAREER"}"#.utf8))
        assert(legacy.tour==nil,"Older responses must decode without a tour")
        let assigned=HeaderSubject(roleTitle:"Career Member",stationTitle:"Station 2",tourTitle:"Blue Watch")
        assert(assigned.headerSubtitle=="Career Member • Station 2 • Blue Watch")
        assert(HeaderSubject(roleTitle:"Career Member",stationTitle:"Station 2",tourTitle:nil).headerSubtitle=="Career Member • Station 2")
        print("PASS: real tour/member API contracts, dynamic fifth/renamed tours, lieutenant links, legacy decoding and header labels")
    }
}
