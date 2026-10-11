import Foundation

public struct DisplayMode: Hashable, Codable, Sendable {
    public let width: Int
    public let height: Int
    public let scale: Double
    public let refreshRate: Double
    public let isHiDPI: Bool

    public init(
        width: Int,
        height: Int,
        scale: Double = 1.0,
        refreshRate: Double = 60.0,
        isHiDPI: Bool = false
    ) {
        self.width = width
        self.height = height
        self.scale = scale
        self.refreshRate = refreshRate
        self.isHiDPI = isHiDPI
    }

    public var aspectRatioString: String {
        guard width > 0 && height > 0 else { return "0:0" }
        let g = gcd(width, height)
        let w = width / g
        let h = height / g
        if (w == 8 && h == 5) || (w == 16 && h == 10) {
            return "16:10"
        }
        return "\(w):\(h)"
    }

    private func gcd(_ a: Int, _ b: Int) -> Int {
        var x = abs(a)
        var y = abs(b)
        while y != 0 {
            let temp = y
            y = x % y
            x = temp
        }
        return max(x, 1)
    }
}
