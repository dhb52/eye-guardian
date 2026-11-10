import AppKit
import Combine
import SwiftUI

private final class GuideAnimation: ObservableObject {
    @Published var bobbing = false
}

struct PermissionGuideView: View {
    let kind: PermissionKind
    let onDragEnded: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var animation = GuideAnimation()

    var body: some View {
        HStack(spacing: 16) {
            tile

            Image(systemName: "arrow.up")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .offset(y: reduceMotion ? 0 : (animation.bobbing ? -4 : 4))
                .opacity(reduceMotion ? 1 : (animation.bobbing ? 1 : 0.45))
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        animation.bobbing = true
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                (
                    Text(L10n.t("PermissionGuideHintPrefix")).foregroundColor(.secondary)
                    + Text(L10n.t(kind.titleKey)).bold().foregroundColor(.primary)
                    + Text(L10n.t("PermissionGuideHintSuffix")).foregroundColor(.secondary)
                )
                .fixedSize(horizontal: false, vertical: true)

                Text(L10n.t("PermissionGuideCompletion"))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 22)
        .frame(width: PermissionGuideLayout.panelSize.width,
               height: PermissionGuideLayout.panelSize.height)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.08))
                )
        )
    }

    private var tile: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundleURL.path))
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)

            Text(L10n.t("AppName"))
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.12))
        )
        .overlay(
            AppBundleDragSource(url: Bundle.main.bundleURL, onEnded: onDragEnded)
        )
        .help(L10n.t("PermissionGuideDragTitle"))
    }
}

struct AppBundleDragSource: NSViewRepresentable {
    let url: URL
    let onEnded: () -> Void

    func makeNSView(context: Context) -> BundleDragView {
        BundleDragView(url: url, onEnded: onEnded)
    }

    func updateNSView(_ nsView: BundleDragView, context: Context) {
        nsView.url = url
        nsView.onEnded = onEnded
    }
}

final class BundleDragView: NSView, NSDraggingSource {
    var url: URL
    var onEnded: (() -> Void)?

    init(url: URL, onEnded: (() -> Void)?) {
        self.url = url
        self.onEnded = onEnded
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 64, height: 64)

        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let frame = NSRect(x: bounds.midX - 32, y: bounds.midY - 32, width: 64, height: 64)
        item.setDraggingFrame(frame, contents: icon)

        let session = beginDraggingSession(with: [item], event: event, source: self)
        session.draggingFormation = .none
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .generic]
    }

    func draggingSession(_ session: NSDraggingSession,
                         endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        onEnded?()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}
