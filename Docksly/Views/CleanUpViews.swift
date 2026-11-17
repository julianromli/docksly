import AppKit
import SwiftUI

enum CleanUpReviewLayout {
    case popover
    case editor
}

struct CleanUpReviewView: View {
    var layout: CleanUpReviewLayout
    @EnvironmentObject private var cleanUp: CleanUpController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            bodyContent
            footer
        }
        .padding(.horizontal, layout == .popover ? 12 : 0)
        .padding(.top, layout == .popover ? 10 : 4)
        .padding(.bottom, layout == .popover ? 10 : 0)
        .frame(maxWidth: layout == .popover ? CleanUpStyle.popoverWidth : .infinity, alignment: .leading)
        .background(ReviewKeyCatcher(
            onReturn: { cleanUp.performPrimary() },
            onEscape: { cleanUp.goBack() },
            onToggle: { cleanUp.toggleFocusedRow() },
            onUp: { cleanUp.moveFocus(by: -1) },
            onDown: { cleanUp.moveFocus(by: 1) }
        ))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityTitle)
    }

    private var accessibilityTitle: String {
        switch cleanUp.phase {
        case .idle:
            return "Clean Up"
        case .review:
            return CleanUpCopy.leftoverHeadline(count: cleanUp.leftoverCount, dockName: cleanUp.currentDockName)
        case .asking:
            return CleanUpCopy.asking(cleanUp.askingCount)
        case .result:
            return CleanUpCopy.resultTitle(quitCount: cleanUp.quitCount)
        }
    }

    @ViewBuilder
    private var header: some View {
        switch cleanUp.phase {
        case .idle:
            EmptyView()
        case .review:
            VStack(alignment: .leading, spacing: 4) {
                Text(CleanUpCopy.leftoverHeadline(count: cleanUp.leftoverCount, dockName: cleanUp.currentDockName))
                    .font(.system(size: layout == .popover ? 13 : 15, weight: .semibold))
                    .lineLimit(1)
                Text(CleanUpCopy.reviewFootnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        case .asking:
            EmptyView()
        case .result:
            VStack(alignment: .leading, spacing: 4) {
                Text(CleanUpCopy.resultTitle(quitCount: cleanUp.quitCount))
                    .font(.system(size: layout == .popover ? 13 : 15, weight: .semibold))
                Text(CleanUpCopy.waitingMessage(names: cleanUp.waiting.map(\.name)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch cleanUp.phase {
        case .idle:
            EmptyView()
        case .review:
            if cleanUp.showsNothingToClean {
                Text("Nothing to clean")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                reviewList
            }
        case .asking:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(CleanUpCopy.asking(cleanUp.askingCount))
                    .font(.system(size: layout == .popover ? 13 : 15, weight: .semibold))
            }
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        case .result:
            waitingList
        }
    }

    private var reviewList: some View {
        let rows = cleanUp.reviewRows
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, app in
                        CleanUpAppRow(
                            app: app,
                            layout: layout,
                            isChecked: cleanUp.isChecked(app.id),
                            isKeeping: cleanUp.isKeeping(app.id),
                            isFocused: cleanUp.focusedIndex == index,
                            onToggle: { cleanUp.toggleChecked(app.id) },
                            onKeep: { cleanUp.alwaysKeep(app) }
                        )
                        .id(app.id)
                        .onTapGesture {
                            cleanUp.focusedIndex = index
                        }
                    }
                }
            }
            .onChange(of: cleanUp.focusedIndex) { index in
                guard rows.indices.contains(index) else { return }
                proxy.scrollTo(rows[index].id, anchor: .center)
            }
        }
        .frame(height: CleanUpStyle.listHeight(rowCount: rows.count))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var waitingList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(cleanUp.waiting) { app in
                    HStack(spacing: 8) {
                        CleanUpAppIcon(app: app)
                        Text(app.name)
                            .font(.system(size: 13))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 8)
                        Text("Waiting to save")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Button("Show") {
                            cleanUp.showWaiting(app)
                        }
                        .buttonStyle(CleanUpSecondaryButtonStyle())
                        .accessibilityLabel("Show \(app.name)")
                        .accessibilityHint("Brings the app forward so you can save or quit it")
                    }
                    .frame(height: CleanUpStyle.reviewRowHeight)
                }
            }
        }
        .frame(height: CleanUpStyle.listHeight(rowCount: max(cleanUp.waiting.count, 1)))
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            switch cleanUp.phase {
            case .idle:
                EmptyView()
            case .review:
                Button("Cancel") { cleanUp.goBack() }
                    .buttonStyle(CleanUpSecondaryButtonStyle())
                    .accessibilityLabel("Cancel Clean Up")
                Button(CleanUpCopy.quitTitle(cleanUp.selectedCount)) {
                    cleanUp.startQuit()
                }
                .buttonStyle(CleanUpPrimaryButtonStyle())
                .disabled(cleanUp.selectedCount == 0)
                .accessibilityLabel(CleanUpCopy.quitTitle(cleanUp.selectedCount))
                .accessibilityHint("Asks the selected apps to quit. Docksly never force quits.")
            case .asking:
                EmptyView()
            case .result:
                Button("Done") { cleanUp.goBack() }
                    .buttonStyle(CleanUpPrimaryButtonStyle())
                    .accessibilityLabel("Done")
            }
        }
    }
}

struct CleanUpAppRow: View {
    var app: CleanUpApp
    var layout: CleanUpReviewLayout
    var isChecked: Bool
    var isKeeping: Bool
    var isFocused: Bool
    var onToggle: () -> Void
    var onKeep: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                CleanUpCheckboxMark(isOn: isChecked)
            }
            .buttonStyle(.plain)
            .disabled(isKeeping)
            .accessibilityLabel("Quit \(app.name)")
            .accessibilityValue(isChecked ? "Selected" : (isKeeping ? "Keeping" : "Not selected"))
            .accessibilityAddTraits(.isButton)
            .opacity(isKeeping ? 0.4 : 1)

            CleanUpAppIcon(app: app)

            Text(app.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !isKeeping, !isChecked, layout == .editor {
                Text("This time only")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if isKeeping {
                Text("Keeping")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "FF9F0A"))
                    .lineLimit(1)
            }

            Button(action: onKeep) {
                Image(systemName: isKeeping ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "FF9F0A"))
                    .frame(width: CleanUpStyle.pinHit, height: CleanUpStyle.pinHit)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isKeeping)
            .help(isKeeping ? "Keeping" : "Always Keep")
            .accessibilityLabel(isKeeping ? "Keeping \(app.name) open" : "Always keep \(app.name) open")
            .accessibilityHint("Adds this app to Apps to Keep Open")
        }
        .padding(.horizontal, 2)
        .frame(height: CleanUpStyle.reviewRowHeight)
        .background {
            if isFocused {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct CleanUpCheckboxMark: View {
    var isOn: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CleanUpStyle.checkboxCorner, style: .continuous)
                .fill(isOn ? Color.accentColor : Color.clear)
            RoundedRectangle(cornerRadius: CleanUpStyle.checkboxCorner, style: .continuous)
                .strokeBorder(isOn ? Color.clear : Color.secondary.opacity(0.5), lineWidth: 1)
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: CleanUpStyle.checkboxSize, height: CleanUpStyle.checkboxSize)
    }
}

struct CleanUpAppIcon: View {
    var app: CleanUpApp
    var size: CGFloat = CleanUpStyle.appIconSize

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size <= 20 ? CleanUpStyle.appIconCorner : 6, style: .continuous))
            .accessibilityHidden(true)
    }

    private var icon: NSImage {
        if let path = app.path, !path.isEmpty {
            return AppIconService.shared.icon(forAppAt: path)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            return AppIconService.shared.icon(forAppAt: url.path)
        }
        return AppIconService.shared.isMissingSymbol
    }
}

struct CleanUpStripView: View {
    @EnvironmentObject private var cleanUp: CleanUpController

    var body: some View {
        HStack(spacing: 10) {
            Text(CleanUpCopy.leftoverHeadline(count: cleanUp.leftoverCount, dockName: cleanUp.currentDockName))
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)

            leftoverIcons

            Spacer(minLength: 8)

            Button("Clean Up") {
                cleanUp.beginReview()
            }
            .buttonStyle(CleanUpPrimaryButtonStyle())
            .accessibilityLabel("Clean Up")
            .accessibilityHint(CleanUpCopy.leftoverHeadline(count: cleanUp.leftoverCount, dockName: cleanUp.currentDockName))
        }
        .padding(.horizontal, DockslyStyle.contentLeading)
        .padding(.trailing, DockslyStyle.trailingInset)
        .frame(height: CleanUpStyle.stripHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(CleanUpCopy.leftoverHeadline(count: cleanUp.leftoverCount, dockName: cleanUp.currentDockName))
    }

    private var leftoverIcons: some View {
        let apps = Array(cleanUp.selection.leftover.prefix(CleanUpStyle.stripMaxIcons))
        let overflow = cleanUp.leftoverCount - apps.count
        return HStack(spacing: 4) {
            ForEach(apps) { app in
                CleanUpAppIcon(app: app, size: CleanUpStyle.stripIconSize)
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(overflow) more")
            }
        }
        .accessibilityHidden(true)
    }
}

struct CleanUpPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: CleanUpStyle.footerButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: CleanUpStyle.footerButtonCorner, style: .continuous)
                    .fill(Color.accentColor.opacity(isEnabled ? 1 : 0.45))
            )
            .scaleEffect(scale(configuration.isPressed))
            .animation(reduceMotion ? nil : DockslyStyle.pressSpring, value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }

    private func scale(_ isPressed: Bool) -> CGFloat {
        if reduceMotion { return 1 }
        return isPressed ? DockslyStyle.pressScale : 1
    }
}

struct CleanUpSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(height: CleanUpStyle.footerButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: CleanUpStyle.footerButtonCorner, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.1 : 0.06))
            )
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? DockslyStyle.pressScale : 1))
            .animation(reduceMotion ? nil : DockslyStyle.pressSpring, value: configuration.isPressed)
    }
}

/// Captures Return, Esc, arrows, and Space while the review is open (macOS 13+).
struct ReviewKeyCatcher: NSViewRepresentable {
    var onReturn: () -> Void
    var onEscape: () -> Void
    var onToggle: () -> Void
    var onUp: () -> Void
    var onDown: () -> Void

    func makeNSView(context: Context) -> ReviewKeyCatcherView {
        let view = ReviewKeyCatcherView()
        view.handlers = self
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ view: ReviewKeyCatcherView, context: Context) {
        view.handlers = self
    }
}

final class ReviewKeyCatcherView: NSView {
    var handlers: ReviewKeyCatcher?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) || event.modifierFlags.contains(.control) {
            super.keyDown(with: event)
            return
        }
        switch event.keyCode {
        case 36, 76:
            handlers?.onReturn()
        case 53:
            handlers?.onEscape()
        case 49:
            handlers?.onToggle()
        case 125:
            handlers?.onDown()
        case 126:
            handlers?.onUp()
        default:
            super.keyDown(with: event)
        }
    }
}

/// Animates the editor window height to follow Clean Up chrome, 200ms ease-out, or a snap when Reduce Motion is on.
struct WindowContentHeightSync: NSViewRepresentable {
    var height: CGFloat
    var reduceMotion: Bool

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.sync(window: view.window, height: height, reduceMotion: reduceMotion)
        }
    }

    private static func sync(window: NSWindow?, height: CGFloat, reduceMotion: Bool) {
        guard let window, height > 0 else { return }
        let contentRect = window.contentRect(forFrameRect: window.frame)
        guard abs(contentRect.height - height) > 1 else { return }
        let newFrame = window.frameRect(forContentRect: NSRect(
            x: contentRect.origin.x,
            y: contentRect.origin.y + (contentRect.height - height),
            width: contentRect.width,
            height: height
        ))
        if reduceMotion {
            window.setFrame(newFrame, display: true, animate: false)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(newFrame, display: true)
        }
    }
}
