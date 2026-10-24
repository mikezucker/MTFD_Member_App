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
        let saved=try JSONSerialization.jsonObject(with:JSONEncoder().encode(content)) as! [String:Any]
        // Models supply defaults for omitted optional collections, so compare
        // every original source field recursively while permitting those defaults.
        func preserved(_ before:Any,_ after:Any){
            if let a=before as? [String:Any],let b=after as? [String:Any] {for (k,v) in a {assert(b[k] != nil,"Lost field \(k)");preserved(v,b[k]!)}}
            else if let a=before as? [Any],let b=after as? [Any] {assert(a.count==b.count);for (v,w) in zip(a,b){preserved(v,w)}}
            else {assert(NSDictionary(dictionary:["v":before]).isEqual(to:["v":after]))}
        }
        preserved(object,saved)
        let session=try JSONDecoder().decode(GuidedSession.self,from:Data(#"{"id":"session","title":"Fixture","courseId":"course","status":"IN_PROGRESS","stage":"PRACTICE","jprIndex":0,"stepIndex":0,"durationMinutes":60,"revision":1,"participants":[],"jprs":[],"observations":{},"selectedScenarios":{"version-1":"scenario-1"}}"#.utf8))
        assert(session.selectedScenarios?["version-1"] == "scenario-1")
        print("JPR content: legacy decoding, expanded decoding, stable scenario IDs, edit/encode round-trip and future fields passed.")
    }
}
