import XCTest
@testable import FoodShare

final class ModelsTests: XCTestCase {
    func testUserDecoding() throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "email": "test@example.com",
            "username": "testuser",
            "avatar_url": "https://example.com/avatar.jpg",
            "created_at": "2026-01-01T00:00:00Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let user = try decoder.decode(User.self, from: data)
        
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.username, "testuser")
    }
    
    func testListingDecoding() throws {
        let json = """
        {
            "id": 1,
            "title": "Fresh Apples",
            "description": "Organic apples",
            "user_id": "123e4567-e89b-12d3-a456-426614174000",
            "image_url": "https://example.com/apples.jpg",
            "latitude": 37.7749,
            "longitude": -122.4194,
            "status": "available",
            "created_at": "2026-01-01T00:00:00Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let listing = try decoder.decode(Listing.self, from: data)
        
        XCTAssertEqual(listing.title, "Fresh Apples")
        XCTAssertEqual(listing.status, .available)
        XCTAssertEqual(listing.latitude, 37.7749)
    }
    
    func testListingStatusEnum() {
        XCTAssertEqual(ListingStatus.available.rawValue, "available")
        XCTAssertEqual(ListingStatus.claimed.rawValue, "claimed")
        XCTAssertEqual(ListingStatus.expired.rawValue, "expired")
    }
}
