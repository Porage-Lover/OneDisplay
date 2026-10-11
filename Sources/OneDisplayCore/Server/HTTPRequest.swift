import Foundation

public struct HTTPRequest: Sendable {
    public let method: String
    public let path: String
    public let queryParameters: [String: String]
    public let headers: [String: String]
    public let body: String?

    public static func parse(raw: String) -> HTTPRequest? {
        let lines = raw.components(separatedBy: "\r\n")
        guard let requestLine = lines.first, !requestLine.isEmpty else { return nil }

        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }

        let method = String(parts[0])
        let fullPath = String(parts[1])

        var path = fullPath
        var queryParams: [String: String] = [:]

        if let queryIndex = fullPath.firstIndex(of: "?") {
            path = String(fullPath[..<queryIndex])
            let queryString = String(fullPath[fullPath.index(after: queryIndex)...])
            for pair in queryString.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
                if kv.count == 2 {
                    let key = kv[0].removingPercentEncoding ?? kv[0]
                    let val = kv[1].removingPercentEncoding ?? kv[1]
                    queryParams[key] = val
                } else if kv.count == 1 {
                    let key = kv[0].removingPercentEncoding ?? kv[0]
                    queryParams[key] = ""
                }
            }
        }

        var headers: [String: String] = [:]
        var bodyStartIndex = -1
        for (index, line) in lines.dropFirst().enumerated() {
            if line.isEmpty {
                bodyStartIndex = index + 2
                break
            }
            let headerParts = line.split(separator: ":", maxSplits: 1)
            if headerParts.count == 2 {
                let key = headerParts[0].trimmingCharacters(in: .whitespaces)
                let val = headerParts[1].trimmingCharacters(in: .whitespaces)
                headers[key] = val
            }
        }

        var body: String? = nil
        if bodyStartIndex != -1 && bodyStartIndex < lines.count {
            body = lines[bodyStartIndex...].joined(separator: "\r\n")
        }

        return HTTPRequest(
            method: method,
            path: path,
            queryParameters: queryParams,
            headers: headers,
            body: body
        )
    }
}
