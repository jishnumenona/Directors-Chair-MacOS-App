//
//  TraitVocabularyTests.swift
//  DirectorsChairCoreTests
//
//  DC-0078: one trait vocabulary. The record's keys are the 25 Big-Five
//  facets the Personality tab shows; older records (25 lowercase keys such
//  as "confidence") are brought onto it on decode without losing a
//  user-set score.
//

import XCTest
@testable import DirectorsChairCore

final class TraitVocabularyTests: XCTestCase {

    func testVocabularyIsFiveCategoriesOfFiveFacets() {
        XCTAssertEqual(TraitVocabulary.categories.map(\.name),
                       ["Openness", "Conscientiousness", "Extraversion", "Agreeableness", "Neuroticism"])
        XCTAssertTrue(TraitVocabulary.categories.allSatisfy { $0.facets.count == 5 })
        XCTAssertEqual(TraitVocabulary.facets.count, 25)
        XCTAssertEqual(Set(TraitVocabulary.facets).count, 25, "no facet twice")
        XCTAssertEqual(Character.defaultTraits(), TraitVocabulary.defaults())
        XCTAssertEqual(TraitVocabulary.facets(in: "agreeableness"),
                       ["Empathy", "Cooperation", "Trust", "Kindness", "Politeness"])
    }

    func testCanonicalNameToleratesCaseSpacingAndHyphens() {
        XCTAssertEqual(TraitVocabulary.canonicalName("creativity"), "Creativity")
        XCTAssertEqual(TraitVocabulary.canonicalName("open mindedness"), "Open-mindedness")
        XCTAssertEqual(TraitVocabulary.canonicalName("SELF_DISCIPLINE"), "Self-discipline")
        XCTAssertEqual(TraitVocabulary.canonicalName("artistic-interest"), "Artistic Interest")
        XCTAssertNil(TraitVocabulary.canonicalName("confidence"), "a legacy key is not a facet")
        XCTAssertNil(TraitVocabulary.canonicalName(""))
    }

    func testNormaliseFoldsAliasesAndKeepsUserSetLegacyScores() {
        var legacyRecord: [String: Double] = [
            "confidence": 85, "empathy": 92, "aggression": 50, "optimism": 50, "anxiety": 50,
            "intelligence": 50, "creativity": 61, "wisdom": 50, "curiosity": 50, "logic": 50,
            "charisma": 50, "humor": 50, "manipulation": 50, "leadership": 50, "loyalty": 50,
            "honesty": 50, "courage": 70, "compassion": 50, "justice": 50, "selflessness": 50,
            "strength": 50, "agility": 50, "stamina": 50, "coordination": 50, "reflexes": 50,
        ]
        let normalised = TraitVocabulary.normalise(legacyRecord)
        XCTAssertEqual(Set(normalised.traits.keys), Set(TraitVocabulary.facets), "exactly the 25 facets")
        XCTAssertEqual(normalised.traits["Empathy"], 92, "a legacy key that IS a facet folds onto it")
        XCTAssertEqual(normalised.traits["Creativity"], 61)
        XCTAssertEqual(normalised.traits["Anxiety"], 50)
        XCTAssertEqual(normalised.traits["Curiosity"], 50)
        XCTAssertEqual(normalised.legacy, ["confidence": 85, "courage": 70],
                       "only user-set scores of non-facets survive; seeded 50s carried nothing")

        // An exact canonical key beats an alias when both are present.
        legacyRecord["Empathy"] = 33
        XCTAssertEqual(TraitVocabulary.normalise(legacyRecord).traits["Empathy"], 33)

        // A record already on the vocabulary is untouched and has no legacy.
        var canonical = TraitVocabulary.defaults()
        canonical["Trust"] = 12
        let again = TraitVocabulary.normalise(canonical)
        XCTAssertEqual(again.traits, canonical)
        XCTAssertTrue(again.legacy.isEmpty)
    }

    func testMemberwiseInitLandsOnTheVocabulary() {
        let character = Character(name: "Alice", traits: ["confidence": 85, "empathy": 92])
        XCTAssertEqual(character.traits.count, 25)
        XCTAssertEqual(character.traits["Empathy"], 92)
        XCTAssertNil(character.traits["confidence"])
        XCTAssertEqual(character.legacyTraits, ["confidence": 85])
        XCTAssertNil(Character(name: "Bob").legacyTraits, "no legacy bucket unless there is something in it")
    }

    /// A project written before DC-0078: lowercase record keys, one of them
    /// set by hand. Decoding brings it onto the vocabulary; the next save
    /// writes canonical keys plus the legacy bucket, and no score is lost.
    func testDecodingAnOldRecordMigratesItsTraits() throws {
        let json = """
        {"name":"Old Timer","traits":{"confidence":85,"empathy":92,"aggression":50,"optimism":50,
         "anxiety":50,"intelligence":50,"creativity":50,"wisdom":50,"curiosity":50,"logic":50,
         "charisma":50,"humor":50,"manipulation":50,"leadership":50,"loyalty":50,"honesty":50,
         "courage":50,"compassion":50,"justice":50,"selflessness":50,"strength":50,"agility":50,
         "stamina":50,"coordination":50,"reflexes":50}}
        """
        let decoded = try JSONDecoder().decode(Character.self, from: Data(json.utf8))
        XCTAssertEqual(Set(decoded.traits.keys), Set(TraitVocabulary.facets))
        XCTAssertEqual(decoded.traits["Empathy"], 92)
        XCTAssertEqual(decoded.legacyTraits, ["confidence": 85])

        let saved = try JSONEncoder().encode(decoded)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        let traits = try XCTUnwrap(object["traits"] as? [String: Double])
        XCTAssertEqual(Set(traits.keys), Set(TraitVocabulary.facets), "the next save writes canonical keys")
        XCTAssertEqual(object["legacy_traits"] as? [String: Double], ["confidence": 85])

        let reloaded = try JSONDecoder().decode(Character.self, from: saved)
        XCTAssertEqual(reloaded.traits, decoded.traits)
        XCTAssertEqual(reloaded.legacyTraits, decoded.legacyTraits)
    }

    func testRecordsOnTheVocabularyOmitTheLegacyKey() throws {
        let saved = try JSONEncoder().encode(Character(name: "Fresh"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        XCTAssertNil(object["legacy_traits"], "no bucket, no key — older readers see the same shape")
    }

    func testArrayFormTraitsRaiseTheNamedFacets() throws {
        let json = #"{"name":"Listed","traits":["curiosity","Open-mindedness","confidence"]}"#
        let decoded = try JSONDecoder().decode(Character.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.traits["Curiosity"], 75)
        XCTAssertEqual(decoded.traits["Open-mindedness"], 75)
        XCTAssertEqual(decoded.traits.count, 25)
        XCTAssertNil(decoded.legacyTraits, "a listed word that is not a facet carries no score to keep")
    }
}
