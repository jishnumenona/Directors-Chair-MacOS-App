// DC-0090: the project-wide preview resolution — stored, defaulted, tolerant.
import XCTest
@testable import DirectorsChairCore

final class PreviewResolutionTests: XCTestCase {
    func testDefaultIsFullHD() {
        XCTAssertEqual(PreviewResolution.default, .hd1080)
        XCTAssertEqual(Project(name: "P").previewResolution, .hd1080)
        XCTAssertEqual(PreviewResolution.hd1080.width, 1920)
        XCTAssertEqual(PreviewResolution.hd1080.height, 1080)
        XCTAssertEqual(PreviewResolution.hd1080.dimensionsLabel, "1920 × 1080")
        for option in PreviewResolution.allCases {
            XCTAssertEqual(option.aspectRatio, "16:9")
            XCTAssertEqual(option.width * 9, option.height * 16, "\(option) is not a 16:9 frame")
        }
    }

    func testRoundTripsUnderItsSnakeCaseKey() throws {
        var project = Project(name: "P")
        project.previewResolution = .uhd4k
        let data = try JSONEncoder().encode(project)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["preview_resolution"] as? String, "4k")
        XCTAssertEqual(try JSONDecoder().decode(Project.self, from: data).previewResolution, .uhd4k)
    }

    func testOlderFilesAndUnknownTokensFallBackToFullHD() throws {
        let base = try JSONEncoder().encode(Project(name: "P"))
        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: base) as? [String: Any])
        json.removeValue(forKey: "preview_resolution")
        let absent = try JSONSerialization.data(withJSONObject: json)
        XCTAssertEqual(try JSONDecoder().decode(Project.self, from: absent).previewResolution, .hd1080)
        json["preview_resolution"] = "8k-someday"
        let unknown = try JSONSerialization.data(withJSONObject: json)
        XCTAssertEqual(try JSONDecoder().decode(Project.self, from: unknown).previewResolution, .hd1080)
        XCTAssertEqual(PreviewResolution.stored(nil), .hd1080)
        XCTAssertEqual(PreviewResolution.stored("720p"), .hd720)
    }
}
