import Foundation
import CoreGraphics
import OneDisplayCore

func printUsage() {
    print("""
    OneDisplay CLI - Unified Display Control & Automation Utility
    
    USAGE:
      onedisplay list
      onedisplay get --display <id> [--brightness] [--contrast]
      onedisplay set --display <id> [--brightness <val>] [--contrast <val>] [--rotate <0|90|180|270>] [--mirror <id|none>] [--xdr <on|off>]
      onedisplay virtual-display create --name <name> --width <w> --height <h>
      onedisplay virtual-display destroy --display <id>
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
    print("Enumerating connected displays...")
    let displays = DisplayManager.shared.detectDisplays()
    for d in displays {
        let typeStr = d.isBuiltIn ? "Built-in" : (d.isVirtual ? "Virtual" : "External")
        print(" - Display ID \(d.id.rawValue): \(d.name) [\(typeStr)] Mode: \(d.currentModeString) Brightness: \(Int(round(d.brightness * 100)))%")
    }

case "get":
    var targetID = CGMainDisplayID()
    for i in 2..<args.count {
        if args[i] == "--display", i + 1 < args.count, let id = UInt32(args[i + 1]) {
            targetID = id
        }
    }
    let hw = DisplayHardwareController.shared.getBrightness(for: targetID) ?? 0.5
    let isBoosted = XDRManager.shared.isBoosted(for: DisplayID(targetID))
    let rot = Int(round(CGDisplayRotation(targetID)))
    let mirrored = CGDisplayIsInMirrorSet(targetID) != 0
    print("Display \(targetID): Brightness=\(Int(round(hw * 100)))% (XDR Boost: \(isBoosted)), Rotation=\(rot)°, Mirrored=\(mirrored)")

case "set":
    var targetID = CGMainDisplayID()
    var brightnessVal: Double? = nil
    var contrastVal: Double? = nil
    var rotateAngle: Int? = nil
    var mirrorMaster: UInt32? = nil
    var clearMirror = false
    var xdrToggle: Bool? = nil

    var i = 2
    while i < args.count {
        if args[i] == "--display", i + 1 < args.count, let id = UInt32(args[i + 1]) {
            targetID = id
            i += 2
        } else if args[i] == "--brightness", i + 1 < args.count {
            let s = args[i + 1].replacingOccurrences(of: "%", with: "")
            if let val = Double(s) {
                brightnessVal = val > 1.6 ? val / 100.0 : val
            }
            i += 2
        } else if args[i] == "--contrast", i + 1 < args.count {
            let s = args[i + 1].replacingOccurrences(of: "%", with: "")
            if let val = Double(s) {
                contrastVal = val > 1.0 ? val / 100.0 : val
            }
            i += 2
        } else if args[i] == "--rotate", i + 1 < args.count, let angle = Int(args[i + 1]) {
            rotateAngle = angle
            i += 2
        } else if args[i] == "--mirror", i + 1 < args.count {
            if args[i + 1] == "none" || args[i + 1] == "off" {
                clearMirror = true
            } else if let mid = UInt32(args[i + 1]) {
                mirrorMaster = mid
            }
            i += 2
        } else if args[i] == "--xdr", i + 1 < args.count {
            xdrToggle = (args[i + 1].lowercased() == "on" || args[i + 1] == "1" || args[i + 1].lowercased() == "true")
            i += 2
        } else {
            i += 1
        }
    }

    let isBuiltIn = CGDisplayIsBuiltin(targetID) != 0
    let bm = BrightnessManager()

    if let xdr = xdrToggle {
        let mult = xdr ? 1.6 : 1.0
        _ = XDRManager.shared.setEDRHeadroom(displayID: DisplayID(targetID), multiplier: mult)
        print("Display \(targetID) XDR Boost set to: \(xdr ? "ON (1.6x headroom)" : "OFF")")
    }

    if let b = brightnessVal {
        _ = bm.applyBrightness(displayID: DisplayID(targetID), sliderValue: b, isBuiltIn: isBuiltIn)
        print("Display \(targetID) brightness set to \(Int(round(b * 100)))%")
    }

    if let c = contrastVal {
        bm.applyContrast(displayID: DisplayID(targetID), contrastValue: c, isBuiltIn: isBuiltIn)
        print("Display \(targetID) contrast set to \(Int(round(c * 100)))%")
    }

    if let r = rotateAngle {
        _ = DisplayLayoutManager.shared.setRotation(for: DisplayID(targetID), angle: r)
        print("Display \(targetID) rotation set to \(r)°")
    }

    if clearMirror {
        _ = DisplayLayoutManager.shared.setMirror(target: DisplayID(targetID), master: nil)
        print("Display \(targetID) mirroring disabled")
    } else if let m = mirrorMaster {
        _ = DisplayLayoutManager.shared.setMirror(target: DisplayID(targetID), master: DisplayID(m))
        print("Display \(targetID) mirrored to display \(m)")
    }

case "virtual-display":
    if args.count > 2 && args[2] == "create" {
        var name = "OneDisplay Virtual"
        var width = 1920
        var height = 1080
        var i = 3
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
        let id = VirtualDisplayManager.shared.createVirtualDisplay(name: name, width: width, height: height)
        print("Created virtual display: \(name) (\(width)x\(height)) with ID: \(id.rawValue)")
    } else if args.count > 2 && args[2] == "destroy" {
        var targetID: DisplayID? = nil
        for i in 3..<args.count {
            if args[i] == "--display", i + 1 < args.count, let id = UInt32(args[i + 1]) {
                targetID = DisplayID(id)
            }
        }
        if let tid = targetID {
            _ = VirtualDisplayManager.shared.destroy(id: tid)
            print("Destroyed virtual display \(tid.rawValue)")
        }
    } else {
        printUsage()
    }

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
