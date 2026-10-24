import Foundation
@main struct JPRContentTests {
    static func main() throws {
        let legacy=Data(#"{"number":"TEST","title":"Synthetic fixture","category":"Fixture","objective":"Objective","conditions":"Conditions","equipment":"Equipment","guidance":"Guidance","standards":"Reference","revisionNotes":"","passingScore":100,"steps":[{"id":"step-1","title":"Step","teach":"Teach","show":"Show","check":"Check","safety":"","required":true,"critical":false}]}"#.utf8)
        let old=try JSONDecoder().decode(GuidedContent.self,from:legacy)
        assert(old.teaching == nil && old.scenarios == nil && old.schemaVersion == nil)
        assert(old.steps.first?.required == true)
        var object=try JSONSerialization.jsonObject(with:legacy) as! [String:Any]
        object["schemaVersion"]=2
        object["futureRoot"]=["keep":true,"null":NSNull(),"array":[1,2,3]]
        object["teaching"]=["performanceObjectives":["Objective"],"prerequisites":["Prior learning"],"requiredEquipment":["Equipment"],"instructorPreparation":["Prepare"],"instructionalSteps":[["id":"teach-1","title":"Teach","instruction":"Instruction","demonstration":"Show","expectedActions":["Action"],"commonMistakes":[["mistake":"Error","correction":"Correction","futureMistake":true]],"safetyConsiderations":["Safety"],"criticalFailures":["Stop"],"futureStep":"keep"]],"references":[["title":"Reference","section":"1","futureReference":"keep"]],"futureTeaching":["keep":true]] as [String:Any]
        object["scenarios"]=[["id":"scenario-1","title":"Scenario","difficulty":"ADVANCED","trainingObjective":"Objective","briefing":"Briefing","requiredEquipment":["Fixture"],"instructorSetup":["Setup"],"expectedActions":["Act"],"complications":["Complication"],"safetyStopConditions":["Stop"],"debriefQuestions":["Question"],"futureScenario":"keep"]]
        var steps=object["steps"] as! [[String:Any]];steps[0]["futureEvaluationStep"]=["keep":true];object["steps"]=steps
        var content=try JSONDecoder().decode(GuidedContent.self,from:JSONSerialization.data(withJSONObject:object))
        assert(content.schemaVersion == 2 && content.teaching?.instructionalSteps.first?.commonMistakes.first?.correction == "Correction")
        assert(content.scenarios?.first?.id == "scenario-1" && content.scenarios?.first?.difficulty == "ADVANCED")
        content.title="Edited by iOS";object["title"]="Edited by iOS"
        content.teaching!.instructionalSteps[0].instruction="Edited on paper"
        content.scenarios![0].briefing="Edited scenario briefing"
        content.steps[0].check="Edited observable requirement"
        var expectedTeaching=object["teaching"] as! [String:Any]
        var expectedTeachingSteps=expectedTeaching["instructionalSteps"] as! [[String:Any]]
        expectedTeachingSteps[0]["instruction"]="Edited on paper";expectedTeaching["instructionalSteps"]=expectedTeachingSteps;object["teaching"]=expectedTeaching
        var expectedScenarios=object["scenarios"] as! [[String:Any]];expectedScenarios[0]["briefing"]="Edited scenario briefing";object["scenarios"]=expectedScenarios
        var expectedSteps=object["steps"] as! [[String:Any]];expectedSteps[0]["check"]="Edited observable requirement";object["steps"]=expectedSteps
        assert(content.passingScore==100 && content.steps[0].required && !content.steps[0].critical)
        let saved=try JSONSerialization.jsonObject(with:JSONEncoder().encode(content)) as! [String:Any]
        // Models supply defaults for omitted optional collections, so compare
        // every original source field recursively while permitting those defaults.
        func preserved(_ before:Any,_ after:Any){
            if let a=before as? [String:Any],let b=after as? [String:Any] {for (k,v) in a {assert(b[k] != nil,"Lost field \(k)");preserved(v,b[k]!)}}
            else if let a=before as? [Any],let b=after as? [Any] {assert(a.count==b.count);for (v,w) in zip(a,b){preserved(v,w)}}
            else {assert(NSDictionary(dictionary:["v":before]).isEqual(to:["v":after]))}
        }
        preserved(object,saved)
        // Typed media edits preserve future metadata at the attachment and step levels.
        let rawMedia=Data(#"{"id":"media-1","assetId":"asset-1","type":"image","caption":"Original","order":0,"instructorNotes":"Restricted","futureMedia":{"keep":true}}"#.utf8)
        var attachment=try JSONDecoder().decode(JPRMedia.self,from:rawMedia)
        content.teaching!.instructionalSteps[0].media=[attachment]
        content.steps[0].media=[attachment]
        attachment.caption="Edited caption";attachment.order=1
        content.teaching!.instructionalSteps[0].media=[attachment]
        let mediaRoundTrip=try JSONDecoder().decode(GuidedContent.self,from:JSONEncoder().encode(content))
        assert(mediaRoundTrip.teaching!.instructionalSteps[0].media[0].caption=="Edited caption")
        assert(mediaRoundTrip.steps[0].media[0].assetId=="asset-1")
        assert(mediaRoundTrip.teaching!.instructionalSteps[0].media[0].string("instructorNotes")=="Restricted")
        if case .object(let future)=mediaRoundTrip.teaching!.instructionalSteps[0].media[0].fields["futureMedia"] {assert(future["keep"] != nil)}else{assertionFailure("Lost future media metadata")}
        var reorder=[attachment,JPRMedia(assetId:"asset-2",type:"video",order:0)]
        reorder.sort{$0.order<$1.order};assert(reorder[0].assetId=="asset-2")
        content.steps[0].media=[];assert(content.steps[0].media.isEmpty)
        let member=try JSONDecoder().decode(JPRMemberDocument.self,from:Data(#"{"id":"v1","revision":1,"content":{"number":"TEST","title":"Fixture","objective":"Objective","equipment":"Equipment","steps":[{"id":"s1","title":"Step","instruction":"Teach","demonstration":"Show","media":[{"id":"m1","assetId":"a1","type":"image","caption":"Fixture","order":0}]}]}}"#.utf8))
        assert(member.content.steps[0].media.count==1)
        print("JPR media: caption edits, ordering, removals, native round trips, unknown metadata and member projection passed.")
        let session=try JSONDecoder().decode(GuidedSession.self,from:Data(#"{"id":"session","title":"Fixture","courseId":"course","status":"IN_PROGRESS","stage":"PRACTICE","jprIndex":0,"stepIndex":0,"durationMinutes":60,"revision":1,"participants":[],"jprs":[],"observations":{},"selectedScenarios":{"version-1":"scenario-1"}}"#.utf8))
        assert(session.selectedScenarios?["version-1"] == "scenario-1")
        print("JPR content: legacy decoding, expanded decoding, stable scenario IDs, edit/encode round-trip and future fields passed.")
    }
}
