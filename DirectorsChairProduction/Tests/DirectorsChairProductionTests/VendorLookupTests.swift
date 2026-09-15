// DirectorsChairProduction/Tests/DirectorsChairProductionTests/VendorLookupTests.swift
//
// DC-0133 — the pure rules behind "autodetect a vendor from a Google link":
// pulling the business name out of a URL, parsing the model's JSON reply, and
// finding an og:image; plus the Vendor model round-trip and view-model CRUD.

import XCTest
@testable import DirectorsChairProduction
@testable import DirectorsChairCore

@MainActor
final class VendorLookupTests: XCTestCase {

    // MARK: - Name extraction

    func testNameFromTheOwnersExampleSearchURL() {
        // The exact link the owner pasted (misspelled, trailing "google").
        let url = "https://www.google.com/search?client=safari&rls=en&q=Arizon+grand+resort+and+spa+google&ie=UTF-8&oe=UTF-8"
        XCTAssertEqual(VendorLookup.vendorName(fromGoogleURL: url), "Arizon grand resort and spa")
    }

    func testNameFromMapsPlaceURL() {
        let url = "https://www.google.com/maps/place/Arizona+Grand+Resort+%26+Spa/@33.36,-111.96,17z"
        XCTAssertEqual(VendorLookup.vendorName(fromGoogleURL: url), "Arizona Grand Resort & Spa")
    }

    func testBareBusinessNameIsUsedAsIs() {
        XCTAssertEqual(VendorLookup.vendorName(fromGoogleURL: "Panavision Woodland Hills"), "Panavision Woodland Hills")
    }

    func testStripsStrayGoogleTokenButNeverEmpties() {
        XCTAssertEqual(VendorLookup.vendorName(fromGoogleURL: "?q=google"), "google",
                       "if 'google' is the only word, keep it rather than return empty")
        XCTAssertEqual(VendorLookup.vendorName(fromGoogleURL: ""), "")
    }

    func testFallsBackToHostWhenNoQuery() {
        XCTAssertEqual(VendorLookup.vendorName(fromGoogleURL: "https://www.arizona-grand.com/rooms"), "arizona grand")
    }

    // MARK: - JSON parsing

    func testParsesFullReply() {
        let json = """
        ```json
        {
          "name": "Arizona Grand Resort & Spa",
          "category": "Hotel",
          "phone": "(602) 438-9000",
          "website": "https://www.arizonagrandresort.com",
          "address": "8000 S Arizona Grand Pkwy",
          "city": "Phoenix", "region": "AZ", "country": "USA",
          "description": "A large all-suite resort and spa.",
          "rating": "4.3",
          "image_url": "https://example.com/photo.jpg"
        }
        ```
        """
        let result = VendorLookup.parse(json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Arizona Grand Resort & Spa")
        XCTAssertEqual(result?.category, "Hotel")
        XCTAssertEqual(result?.city, "Phoenix")
        XCTAssertEqual(result?.rating ?? 0, 4.3, accuracy: 0.001, "rating tolerated as a string")
        XCTAssertEqual(result?.imageUrl, "https://example.com/photo.jpg")
    }

    func testParseReturnsNilWhenNothingUsable() {
        XCTAssertNil(VendorLookup.parse("not json"))
        XCTAssertNil(VendorLookup.parse("{\"category\":\"Hotel\"}"),
                     "no name/website/address/phone means no usable vendor")
    }

    // MARK: - og:image scraping

    func testFindsOgImageInEitherAttributeOrder() {
        let html1 = "<html><head><meta property=\"og:image\" content=\"https://cdn.site.com/hero.jpg\"></head></html>"
        XCTAssertEqual(VendorLookup.ogImageURL(inHTML: html1, pageURL: URL(string: "https://site.com"))?.absoluteString,
                       "https://cdn.site.com/hero.jpg")

        let html2 = "<meta content=\"/img/hero.png\" property=\"og:image\" />"
        XCTAssertEqual(VendorLookup.ogImageURL(inHTML: html2, pageURL: URL(string: "https://site.com/page"))?.absoluteString,
                       "https://site.com/img/hero.png", "relative og:image resolved against the page")

        XCTAssertNil(VendorLookup.ogImageURL(inHTML: "<html></html>", pageURL: nil))
    }

    // MARK: - Vendor model round-trip

    func testVendorEncodesWithSnakeCaseAndDecodesBack() throws {
        let vendor = Vendor(name: "Arizona Grand Resort & Spa", category: "Hotel",
                            phone: "(602) 438-9000", website: "https://www.arizonagrandresort.com",
                            city: "Phoenix", region: "AZ", country: "USA",
                            imagePath: "assets/vendors/abc.jpg",
                            sourceUrl: "https://www.google.com/search?q=arizona+grand",
                            rating: 4.3)
        let data = try JSONEncoder().encode(vendor)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["image_path"] as? String, "assets/vendors/abc.jpg")
        XCTAssertEqual(json["source_url"] as? String, "https://www.google.com/search?q=arizona+grand")

        let decoded = try JSONDecoder().decode(Vendor.self, from: data)
        XCTAssertEqual(decoded, vendor)
        XCTAssertEqual(decoded.locationLine, "Phoenix, AZ, USA")
    }

    func testVendorDecodesLenientlyFromPartialJSON() throws {
        let partial = "{\"name\":\"Local Catering\"}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Vendor.self, from: partial)
        XCTAssertEqual(decoded.name, "Local Catering")
        XCTAssertTrue(decoded.phone.isEmpty)
        XCTAssertNil(decoded.imagePath)
        XCTAssertFalse(decoded.id.isEmpty, "a missing id gets a fresh UUID")
    }

    func testProjectBudgetCarriesVendors() throws {
        var budget = ProjectBudget()
        budget.vendors = [Vendor(name: "A"), Vendor(name: "B")]
        let data = try JSONEncoder().encode(budget)
        let decoded = try JSONDecoder().decode(ProjectBudget.self, from: data)
        XCTAssertEqual(decoded.vendors.map(\.name), ["A", "B"])
        // A budget written before this feature (no "vendors" key) still decodes.
        let legacy = "{\"total_budget\": 1000}".data(using: .utf8)!
        XCTAssertTrue(try JSONDecoder().decode(ProjectBudget.self, from: legacy).vendors.isEmpty)
    }

    // MARK: - View-model CRUD

    func testViewModelVendorCRUD() {
        let vm = BudgetViewModel()
        var changed = 0
        vm.onBudgetChanged = { _ in changed += 1 }

        let v = Vendor(name: "Arizona Grand Resort & Spa", category: "Hotel")
        vm.addVendor(v)
        XCTAssertEqual(vm.vendors.count, 1)

        var edited = v
        edited.phone = "(602) 438-9000"
        vm.updateVendor(edited)
        XCTAssertEqual(vm.vendors.first?.phone, "(602) 438-9000")

        vm.removeVendor(edited)
        XCTAssertTrue(vm.vendors.isEmpty)
        XCTAssertEqual(changed, 3, "each mutation persisted once")
    }
}
