//
//  SnippetIcon.swift
//

import SwiftUI
import AppKit

/// A classic heart shape: two rounded lobes at top, pointed bottom.
/// Returns a path suitable for use as a cutout (even-odd fill) or as a filled overlay.
private func heartPath(in rect: CGRect) -> Path {
    var path = Path()
    let w = rect.width
    let h = rect.height
    let x = rect.minX
    let y = rect.minY

    // Start at the top-center dip between the two lobes
    path.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.28))

    // Right lobe: arc up and over to the right side
    path.addCurve(
        to: CGPoint(x: x + w, y: y + h * 0.32),
        control1: CGPoint(x: x + w * 0.5, y: y - h * 0.04),
        control2: CGPoint(x: x + w, y: y)
    )
    // Right side sweeping down to the bottom point
    path.addCurve(
        to: CGPoint(x: x + w * 0.5, y: y + h),
        control1: CGPoint(x: x + w, y: y + h * 0.65),
        control2: CGPoint(x: x + w * 0.62, y: y + h * 0.86)
    )
    // Left side sweeping up from the bottom point
    path.addCurve(
        to: CGPoint(x: x, y: y + h * 0.32),
        control1: CGPoint(x: x + w * 0.38, y: y + h * 0.86),
        control2: CGPoint(x: x, y: y + h * 0.65)
    )
    // Left lobe: arc up and over back to the top-center dip
    path.addCurve(
        to: CGPoint(x: x + w * 0.5, y: y + h * 0.28),
        control1: CGPoint(x: x, y: y),
        control2: CGPoint(x: x + w * 0.5, y: y - h * 0.04)
    )
    path.closeSubpath()
    return path
}

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path { heartPath(in: rect) }
}

/// SwiftUI view displaying the clipboard icon with a heart cutout.
struct SnippetIconView: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)

            // Board: a clean rounded rect, sized to read well at 18pt.
            let boardW = s * 0.74
            let boardH = s * 0.82
            // Slightly less curvature on the board edges (leave the clip as a capsule).
            let cornerR = boardW * 0.13

            // Pill: slightly narrower than before to match the reference.
            // Important: it overlaps the board, but we do NOT use even-odd fill anymore,
            // so we avoid the overlap "toggle" artifact.
            let pillW = boardW * 0.62
            let pillH = boardH * 0.16

            // Push the board down so the clip protrudes above it.
            let boardY = (geo.size.height - boardH) / 2 + s * 0.05
            // Place the clip higher so its top is clearly above the board.
            // (Clip bottom still overlaps the board slightly.)
            let pillY = boardY - pillH * 0.55
            let pillCenterY = pillY + pillH / 2

            // Small "slot" cutout on the clip to avoid the battery look.
            let slotW = pillW * 0.6
            let slotH = pillH * 0.4
            let slotCenterY = pillY + pillH * 0.58

            let heartSize = boardW * 0.68

            ZStack {
                RoundedRectangle(cornerSize: CGSize(width: cornerR, height: cornerR), style: .continuous)
                    // Template images use alpha only. Use solid black to ensure consistent opacity.
                    .fill(Color.black)
                    .frame(width: boardW, height: boardH)
                    .position(x: geo.size.width / 2, y: boardY + boardH / 2)

                Capsule(style: .continuous)
                    .fill(Color.black)
                    .frame(width: pillW, height: pillH)
                    .position(x: geo.size.width / 2, y: pillCenterY)

                Capsule(style: .continuous)
                    .fill(Color.black)
                    .frame(width: slotW, height: slotH)
                    .position(x: geo.size.width / 2, y: slotCenterY)
                    .blendMode(.destinationOut)

                // Punch the heart out so the menu bar background shows through.
                HeartShape()
                    .fill(Color.black)
                    .frame(width: heartSize, height: heartSize)
                    .position(x: geo.size.width / 2, y: boardY + boardH * 0.55)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Provides methods for generating an NSImage of the snippet icon for macOS menu bar usage.
enum SnippetMenubarIcon {
    @MainActor
    static func makeTemplateImage(pointSize: CGFloat = 18, scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2) -> NSImage {
        let view = SnippetIconView()
            .frame(width: pointSize, height: pointSize)

        let renderer = ImageRenderer(content: view)
        renderer.scale = scale

        guard let nsImage = renderer.nsImage else {
            return NSImage(size: NSSize(width: pointSize, height: pointSize))
        }

        // Template icon: system tints it appropriately for the menu bar,
        // and the heart cutout shows the menu bar background through.
        nsImage.isTemplate = true
        nsImage.size = NSSize(width: pointSize, height: pointSize)
        return nsImage
    }
}
