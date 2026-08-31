// DC-0090: one delivered size for generated previews.
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
import DirectorsChairCore
@testable import DirectorsChairServices

final class ImageTargetSizeTests: XCTestCase {
    private let fullHD = ImageTargetSize(PreviewResolution.hd1080)

    func testProjectResolutionsMapToWireShapeAndSizeClass() {
        XCTAssertEqual(fullHD.width, 1920)
        XCTAssertEqual(fullHD.height, 1080)
        XCTAssertEqual(fullHD.aspectRatio, "16:9")
        XCTAssertEqual(fullHD.cloudSizeClass, "2K", "Full HD asks for 2K and scales down")
        XCTAssertEqual(ImageTargetSize(PreviewResolution.hd720).cloudSizeClass, "1K")
        XCTAssertEqual(ImageTargetSize(PreviewResolution.uhd4k).cloudSizeClass, "4K")
        XCTAssertEqual(ImageTargetSize(width: 1000, height: 1000).aspectRatio, "1:1")
        XCTAssertEqual(ImageTargetSize(width: 1080, height: 1920).aspectRatio, "9:16")
    }

    func testOnDeviceFrameKeepsTheShapeWithinTheMemoryBudget() {
        for target in PreviewResolution.allCases.map(ImageTargetSize.init) {
            for maxArea in [640 * 640, 832 * 832, 1024 * 1024] {
                let frame = target.onDeviceFrame(maxArea: maxArea)
                XCTAssertEqual(frame.width % 16, 0)
                XCTAssertEqual(frame.height % 16, 0)
                XCTAssertLessThanOrEqual(frame.width * frame.height, Int(Double(maxArea) * 1.05),
                                         "\(target) at \(maxArea) drew \(frame)")
                let ratio = Double(frame.width) / Double(frame.height)
                XCTAssertEqual(ratio, 16.0 / 9.0, accuracy: 0.05)
            }
        }
        // A small target is drawn as asked, not blown up.
        let small = ImageTargetSize(width: 768, height: 432).onDeviceFrame(maxArea: 1024 * 1024)
        XCTAssertEqual(small.width, 768)
        XCTAssertEqual(small.height, 432)
    }

    func testCloudBodyCarriesTheSizeClassOnlyWhenATargetIsSet() {
        let plain = ImageGenerationRequest(prompt: "a road")
        XCTAssertNil(AIServiceClient.cloudImageBody(for: plain, preferredModel: nil)["image_size"])
        let sized = ImageGenerationRequest(prompt: "a road", targetSize: fullHD)
        let body = AIServiceClient.cloudImageBody(for: sized, preferredModel: nil)
        XCTAssertEqual(body["image_size"] as? String, "2K")
        XCTAssertEqual(body["aspect_ratio"] as? String, "16:9")
    }

    func testResamplerDeliversTheExactSizeAndLeavesMatchingPicturesAlone() throws {
        let square = try XCTUnwrap(Self.png(width: 1024, height: 1024, fill: (1, 0, 0)))
        let delivered = try XCTUnwrap(ImageResampler.resample(square, to: fullHD))
        let dims = try XCTUnwrap(ImageResampler.dimensions(of: delivered))
        XCTAssertEqual(dims.width, 1920)
        XCTAssertEqual(dims.height, 1080)
        let already = try XCTUnwrap(Self.png(width: 1920, height: 1080, fill: (0, 1, 0)))
        XCTAssertEqual(ImageResampler.resample(already, to: fullHD), already, "same size = same bytes")
        XCTAssertNil(ImageResampler.resample(Data("not a picture".utf8), to: fullHD))
    }

    func testMergeRepaintsOnlyInsideTheMarkedSpots() throws {
        let source = try XCTUnwrap(Self.png(width: 200, height: 100, fill: (1, 0, 0)))     // red
        let edited = try XCTUnwrap(Self.png(width: 100, height: 50, fill: (0, 0, 1)))      // blue, half size
        let region = EditRegion(x: 0.5, y: 0.5, radius: 0.2)   // centre, 20 px radius
        let merged = try XCTUnwrap(ImageResampler.merge(edited: edited, ontoSource: source, regions: [region]))
        let dims = try XCTUnwrap(ImageResampler.dimensions(of: merged))
        XCTAssertEqual(dims.width, 200)
        XCTAssertEqual(dims.height, 100)
        let centre = try XCTUnwrap(Self.pixel(in: merged, x: 100, y: 50))
        let corner = try XCTUnwrap(Self.pixel(in: merged, x: 5, y: 5))
        XCTAssertGreaterThan(centre.b, 200, "centre repainted blue: \(centre)")
        XCTAssertLessThan(centre.r, 50)
        XCTAssertGreaterThan(corner.r, 200, "corner kept red: \(corner)")
        XCTAssertLessThan(corner.b, 50)
    }

    // MARK: - Fixtures

    static func png(width: Int, height: Int, fill: (CGFloat, CGFloat, CGFloat)) -> Data? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(red: fill.0, green: fill.1, blue: fill.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }

    /// RGB of one pixel (top-left origin).
    static func pixel(in data: Data, x: Int, y: Int) -> (r: Int, g: Int, b: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var bytes = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return (Int(bytes[0]), Int(bytes[1]), Int(bytes[2]))
    }
}
