import XCTest
@testable import OneDisplayCore

final class ServerTests: XCTestCase {
    func testHTTPRequestParsing() {
        let raw = "GET /command/set?brightness=80%&display=1 HTTP/1.1\r\nHost: localhost:8969\r\n\r\n"
        let req = HTTPRequest.parse(raw: raw)
        XCTAssertEqual(req?.method, "GET")
        XCTAssertEqual(req?.path, "/command/set")
        XCTAssertEqual(req?.queryParameters["brightness"], "80%")
        XCTAssertEqual(req?.queryParameters["display"], "1")
    }

    func testHTTPResponseFormatting() {
        let res = HTTPResponse(statusCode: 200, statusText: "OK", body: "{\"status\":\"ok\"}")
        let raw = res.formattedResponse()
        XCTAssertTrue(raw.contains("HTTP/1.1 200 OK"))
        XCTAssertTrue(raw.contains("Content-Length: 15"))
    }

    func testHTTPServerRouteCommandSet() {
        let server = HTTPServer()
        let raw = "GET /command/set?display=1&brightness=75% HTTP/1.1\r\nHost: localhost:8969\r\n\r\n"
        let req = HTTPRequest.parse(raw: raw)!
        let res = server.route(request: req)
        XCTAssertEqual(res.statusCode, 200)
        XCTAssertTrue(res.body.contains("\"brightness\": 0.75"))
    }

    func testHTTPServerRouteInvalidCommand() {
        let server = HTTPServer()
        let raw = "GET /command/unknown HTTP/1.1\r\nHost: localhost:8969\r\n\r\n"
        let req = HTTPRequest.parse(raw: raw)!
        let res = server.route(request: req)
        XCTAssertEqual(res.statusCode, 404)
    }
}
