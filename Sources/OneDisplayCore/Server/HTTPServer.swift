import Foundation
import Network

public final class HTTPServer: @unchecked Sendable {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "onedisplay.server.queue")
    private let ddcController: DDCController
    private let brightnessManager: BrightnessManager
    private let virtualDisplayManager: VirtualDisplayManager
    private var token: String?
    public private(set) var isRunning: Bool = false
    private let lock = NSLock()

    public init(
        ddcController: DDCController = DDCController(),
        brightnessManager: BrightnessManager = BrightnessManager(),
        virtualDisplayManager: VirtualDisplayManager = VirtualDisplayManager()
    ) {
        self.ddcController = ddcController
        self.brightnessManager = brightnessManager
        self.virtualDisplayManager = virtualDisplayManager
    }

    public func start(port: UInt16 = 8969, token: String? = nil) throws {
        lock.lock()
        defer { lock.unlock() }

        self.token = token
        let params = NWParameters.tcp
        let nwPort = NWEndpoint.Port(rawValue: port) ?? 8969
        let nwListener = try NWListener(using: params, on: nwPort)

        nwListener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        nwListener.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                self?.isRunning = true
            }
        }

        nwListener.start(queue: queue)
        self.listener = nwListener
        self.isRunning = true
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self = self, let data = data, let raw = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            guard let request = HTTPRequest.parse(raw: raw) else {
                let response = HTTPResponse.badRequest(error: "Malformed HTTP request")
                self.send(response: response, on: connection)
                return
            }

            if let token = self.token {
                let authHeader = request.headers["Authorization"]
                let tokenParam = request.queryParameters["token"]
                let authorized = (authHeader == "Bearer \(token)") || (tokenParam == token)
                if !authorized {
                    let response = HTTPResponse.unauthorized()
                    self.send(response: response, on: connection)
                    return
                }
            }

            let response = self.route(request: request)
            self.send(response: response, on: connection)
        }
    }

    public func route(request: HTTPRequest) -> HTTPResponse {
        switch request.path {
        case "/command/list":
            let active = virtualDisplayManager.activeDisplays()
            let listJson = "{\"displays\": [\(active.map { "{\"id\": \($0.id.rawValue), \"name\": \"\($0.name)\"}" }.joined(separator: ","))]}"
            return HTTPResponse.ok(json: listJson)

        case "/command/get":
            guard let displayStr = request.queryParameters["display"], let displayRaw = UInt32(displayStr) else {
                return HTTPResponse.badRequest(error: "Missing or invalid 'display' parameter")
            }
            let displayID = DisplayID(displayRaw)
            if request.queryParameters.keys.contains("brightness") {
                let b = ddcController.read(displayID: displayID, opcode: .luminance) ?? 50
                return HTTPResponse.ok(json: "{\"display\": \(displayRaw), \"brightness\": \(b)}")
            } else if request.queryParameters.keys.contains("volume") {
                let v = ddcController.read(displayID: displayID, opcode: .audioVolume) ?? 25
                return HTTPResponse.ok(json: "{\"display\": \(displayRaw), \"volume\": \(v)}")
            }
            return HTTPResponse.ok(json: "{\"display\": \(displayRaw)}")

        case "/command/set":
            guard let displayStr = request.queryParameters["display"], let displayRaw = UInt32(displayStr) else {
                return HTTPResponse.badRequest(error: "Missing or invalid 'display' parameter")
            }
            let displayID = DisplayID(displayRaw)
            if let bStr = request.queryParameters["brightness"] {
                let clean = bStr.replacingOccurrences(of: "%", with: "")
                if let val = Double(clean) {
                    let normalized = val > 1.0 ? val / 100.0 : val
                    let level = brightnessManager.applyBrightness(displayID: displayID, sliderValue: normalized)
                    return HTTPResponse.ok(json: "{\"display\": \(displayRaw), \"brightness\": \(level.sliderValue)}")
                }
            }
            if let vStr = request.queryParameters["volume"] {
                let clean = vStr.replacingOccurrences(of: "%", with: "")
                if let val = UInt16(clean) {
                    ddcController.write(displayID: displayID, opcode: .audioVolume, value: val)
                    return HTTPResponse.ok(json: "{\"display\": \(displayRaw), \"volume\": \(val)}")
                }
            }
            return HTTPResponse.ok(json: "{\"status\": \"updated\"}")

        case "/stream":
            return HTTPResponse(statusCode: 200, statusText: "OK", headers: [
                "Content-Type": "text/event-stream",
                "Cache-Control": "no-cache",
                "Connection": "keep-alive"
            ], body: "event: ping\ndata: {}\n\n")

        default:
            return HTTPResponse.notFound()
        }
    }

    private func send(response: HTTPResponse, on connection: NWConnection) {
        let str = response.formattedResponse()
        let data = Data(str.utf8)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
