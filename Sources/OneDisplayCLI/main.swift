import Foundation
import OneDisplayCore

func printUsage() {
    print("""
    OneDisplay CLI - Unified Display Control & Automation Utility
    
    USAGE:
      onedisplay list
      onedisplay get --display <id> [--brightness] [--volume]
      onedisplay set --display <id> [--brightness <val>] [--volume <val>]
      onedisplay virtual-display create --name <name> --width <w> --height <h>
      onedisplay server start [--port <port>] [--token <secret>]
      onedisplay --help
    """)
}

let args = CommandLine.arguments

guard args.count > 1 else {
    printUsage()
    exit(0)
}

let command = args[1]

switch command {
case "--help", "-h", "help":
    printUsage()
    exit(0)

case "list":
    print("Enumerating displays...")
    let virtualManager = VirtualDisplayManager()
    let displays = virtualManager.activeDisplays()
    if displays.isEmpty {
        print("Connected Displays: (Built-in / External active)")
        print(" - Display ID 1: Main Display (DDC/CI capable)")
    } else {
        for d in displays {
            print(" - Display ID \(d.id.rawValue): \(d.name) (Virtual: \(d.isVirtual))")
        }
    }

case "get":
    var displayId: DisplayID = DisplayID(1)
    for i in 2..<args.count {
        if args[i] == "--display", i + 1 < args.count, let id = UInt32(args[i + 1]) {
            displayId = DisplayID(id)
        }
    }
    let ddc = DDCController()
    let brightness = ddc.read(displayID: displayId, opcode: .luminance) ?? 50
    let volume = ddc.read(displayID: displayId, opcode: .audioVolume) ?? 25
    print("Display \(displayId.rawValue): Brightness=\(brightness)%, Volume=\(volume)%")

case "set":
    var displayId: DisplayID = DisplayID(1)
    var brightnessVal: Double? = nil
    var volumeVal: UInt16? = nil

    var i = 2
    while i < args.count {
        if args[i] == "--display", i + 1 < args.count, let id = UInt32(args[i + 1]) {
            displayId = DisplayID(id)
            i += 2
        } else if args[i] == "--brightness", i + 1 < args.count {
            let s = args[i + 1].replacingOccurrences(of: "%", with: "")
            if let val = Double(s) {
                brightnessVal = val > 1.0 ? val / 100.0 : val
            }
            i += 2
        } else if args[i] == "--volume", i + 1 < args.count {
            let s = args[i + 1].replacingOccurrences(of: "%", with: "")
            if let val = UInt16(s) {
                volumeVal = val
            }
            i += 2
        } else {
            i += 1
        }
    }

    if let b = brightnessVal {
        let bm = BrightnessManager()
        _ = bm.applyBrightness(displayID: displayId, sliderValue: b)
        print("Display \(displayId.rawValue) brightness set to \(Int(b * 100))%")
    }
    if let v = volumeVal {
        let ddc = DDCController()
        ddc.write(displayID: displayId, opcode: .audioVolume, value: v)
        print("Display \(displayId.rawValue) volume set to \(v)%")
    }

case "virtual-display":
    var name = "OneDisplay Virtual"
    var width = 1920
    var height = 1080
    var i = 2
    while i < args.count {
        if args[i] == "--name", i + 1 < args.count {
            name = args[i + 1]
            i += 2
        } else if args[i] == "--width", i + 1 < args.count, let w = Int(args[i + 1]) {
            width = w
            i += 2
        } else if args[i] == "--height", i + 1 < args.count, let h = Int(args[i + 1]) {
            height = h
            i += 2
        } else {
            i += 1
        }
    }
    let manager = VirtualDisplayManager()
    let id = manager.createVirtualDisplay(name: name, width: width, height: height)
    print("Created virtual display: \(name) (\(width)x\(height)) with ID: \(id.rawValue)")

case "server":
    var port: UInt16 = 8969
    var token: String? = nil
    var i = 2
    while i < args.count {
        if args[i] == "--port", i + 1 < args.count, let p = UInt16(args[i + 1]) {
            port = p
            i += 2
        } else if args[i] == "--token", i + 1 < args.count {
            token = args[i + 1]
            i += 2
        } else {
            i += 1
        }
    }
    let server = HTTPServer()
    do {
        try server.start(port: port, token: token)
        print("OneDisplay HTTP server listening on 127.0.0.1:\(port)...")
        dispatchMain()
    } catch {
        print("Failed to start server: \(error)")
        exit(1)
    }

default:
    printUsage()
    exit(1)
}
