import Foundation

public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let statusText: String
    public var headers: [String: String]
    public let body: String

    public init(
        statusCode: Int,
        statusText: String,
        headers: [String: String] = [:],
        body: String = ""
    ) {
        self.statusCode = statusCode
        self.statusText = statusText
        self.headers = headers
        self.body = body
        if self.headers["Content-Type"] == nil {
            self.headers["Content-Type"] = "application/json"
        }
        if self.headers["Content-Length"] == nil {
            self.headers["Content-Length"] = "\(body.utf8.count)"
        }
        if self.headers["Connection"] == nil {
            self.headers["Connection"] = "close"
        }
    }

    public func formattedResponse() -> String {
        var str = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        for (k, v) in headers {
            str += "\(k): \(v)\r\n"
        }
        str += "\r\n\(body)"
        return str
    }

    public static func ok(json: String) -> HTTPResponse {
        return HTTPResponse(statusCode: 200, statusText: "OK", body: json)
    }

    public static func badRequest(error: String) -> HTTPResponse {
        let json = "{\"error\": \"\(error)\"}"
        return HTTPResponse(statusCode: 400, statusText: "Bad Request", body: json)
    }

    public static func unauthorized() -> HTTPResponse {
        let json = "{\"error\": \"Unauthorized\"}"
        return HTTPResponse(statusCode: 401, statusText: "Unauthorized", body: json)
    }

    public static func notFound() -> HTTPResponse {
        let json = "{\"error\": \"Not Found\"}"
        return HTTPResponse(statusCode: 404, statusText: "Not Found", body: json)
    }
}
