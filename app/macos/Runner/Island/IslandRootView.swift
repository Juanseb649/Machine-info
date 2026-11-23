import SwiftUI

/// Actions the SwiftUI tree asks the panel controller to perform.
struct IslandActions {
  var hoverChanged: (Bool) -> Void = { _ in }
  var open: () -> Void = {}
  var toggle: () -> Void = {}
  var dismiss: () -> Void = {}
  var quit: () -> Void = {}
}

/// Top-level view hosted by the panel. The black silhouette morphs between
/// the compact and the expanded size with a spring, always pinned to the
/// top edge of the screen.
struct IslandRootView: View {
  @ObservedObject var state: IslandState
  let actions: IslandActions

  private var size: CGSize {
    state.isExpanded ? NotchGeometry.expandedSize : state.geometry.compactSize
  }

  var body: some View {
    ZStack(alignment: .top) {
      NotchShape(topRadius: state.isExpanded ? 14 : 6,
                 bottomRadius: state.isExpanded ? 30 : state.geometry.height / 2.4)
        .fill(IslandPalette.body)
        .shadow(color: .black.opacity(state.isExpanded ? 0.45 : 0), radius: 18, y: 8)

      Group {
        if state.isExpanded {
          IslandExpandedView(payload: state.payload, geometry: state.geometry, onOpen: actions.open)
            .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
        } else {
          IslandCompactView(payload: state.payload, geometry: state.geometry)
            .transition(.opacity)
        }
      }
      .padding(.horizontal, state.isExpanded ? 14 : 6)
    }
    .frame(width: size.width, height: size.height)
    .contentShape(NotchShape(topRadius: 0, bottomRadius: 20))
    .onHover(perform: actions.hoverChanged)
    .onTapGesture(count: 2, perform: actions.open)
    .onTapGesture(perform: actions.toggle)
    .contextMenu {
      Button("Abrir Machine Info", action: actions.open)
      Button("Ocultar la isla hasta la próxima vez", action: actions.dismiss)
      Divider()
      Button("Salir de Machine Info", action: actions.quit)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .animation(.spring(response: 0.42, dampingFraction: 0.78), value: state.isExpanded)
    .animation(.easeInOut(duration: 0.25), value: state.geometry)
    .opacity(state.isVisible ? 1 : 0)
    .animation(.easeOut(duration: 0.2), value: state.isVisible)
  }
}
