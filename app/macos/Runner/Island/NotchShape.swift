import SwiftUI

/// Silhouette of the island: flush with the top edge, with small concave
/// "ears" where it meets the menu bar and rounded bottom corners, like the
/// camera housing it extends. Both radii animate when the island grows.
struct NotchShape: Shape {
  var topRadius: CGFloat
  var bottomRadius: CGFloat

  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(topRadius, bottomRadius) }
    set {
      topRadius = newValue.first
      bottomRadius = newValue.second
    }
  }

  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    let tr = min(topRadius, w / 4)
    let br = min(bottomRadius, (w - 2 * tr) / 2, h - tr)

    var p = Path()
    p.move(to: CGPoint(x: rect.minX, y: rect.minY))
    p.addQuadCurve(to: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
                   control: CGPoint(x: rect.minX + tr, y: rect.minY))
    p.addLine(to: CGPoint(x: rect.minX + tr, y: rect.minY + h - br))
    p.addQuadCurve(to: CGPoint(x: rect.minX + tr + br, y: rect.minY + h),
                   control: CGPoint(x: rect.minX + tr, y: rect.minY + h))
    p.addLine(to: CGPoint(x: rect.minX + w - tr - br, y: rect.minY + h))
    p.addQuadCurve(to: CGPoint(x: rect.minX + w - tr, y: rect.minY + h - br),
                   control: CGPoint(x: rect.minX + w - tr, y: rect.minY + h))
    p.addLine(to: CGPoint(x: rect.minX + w - tr, y: rect.minY + tr))
    p.addQuadCurve(to: CGPoint(x: rect.minX + w, y: rect.minY),
                   control: CGPoint(x: rect.minX + w - tr, y: rect.minY))
    p.closeSubpath()
    return p
  }
}
