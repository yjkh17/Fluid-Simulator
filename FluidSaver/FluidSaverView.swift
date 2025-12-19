import ScreenSaver
import AppKit

@objc(FluidSaverView)
final class FluidSaverView: ScreenSaverView {

    private var t: CGFloat = 0

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 60.0
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        animationTimeInterval = 1.0 / 60.0
    }

    override func animateOneFrame() {
        t += 0.01
        needsDisplay = true
    }

    override func draw(_ rect: NSRect) {
        let v = (sin(t) * 0.5 + 0.5)
        NSColor(calibratedWhite: v, alpha: 1).setFill()
        rect.fill()

        let s = "Running ✅"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.red,
            .font: NSFont.systemFont(ofSize: 32, weight: .bold)
        ]
        s.draw(at: CGPoint(x: 40, y: 40), withAttributes: attrs)
    }
}
