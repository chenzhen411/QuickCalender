import Foundation
import CoreGraphics

public enum CalendarPopupLayout {
    public static let preferredSize = CGSize(width: 400, height: 680)
    public static let margin: CGFloat = 8

    /// Leave room for AppKit's popover border/arrow in addition to the screen margin.
    public static func contentSize(visibleFrame: CGRect) -> CGSize {
        CGSize(width: max(1, min(preferredSize.width, visibleFrame.width - 2 * margin - 24)),
               height: max(1, min(preferredSize.height, visibleFrame.height - 2 * margin - 24)))
    }

    public static func constrainedFrame(_ frame: CGRect, visibleFrame: CGRect) -> CGRect {
        let inset = min(margin, max(0, min(visibleFrame.width, visibleFrame.height) / 4))
        let bounds = visibleFrame.insetBy(dx: inset, dy: inset)
        let size = CGSize(width: min(frame.width, bounds.width), height: min(frame.height, bounds.height))
        return CGRect(x: min(max(frame.minX, bounds.minX), bounds.maxX - size.width),
                      y: min(max(frame.minY, bounds.minY), bounds.maxY - size.height),
                      width: size.width, height: size.height)
    }
}
