import AppKit
import SwiftUI

enum CleanUpReviewLayout {
    case popover
    case editor
}

// MARK: - Review (popover and editor)

struct CleanUpReviewView: View {
    var layout: CleanUpReviewLayout
    @EnvironmentObject private var cleanUp: CleanUpController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if cleanUp.phase == .done {
                CleanUpAllClearView(layout: layout)
                    .transition(.opacity.animation(reduceMotion ? CleanUpStyle.fade150 : CleanUpStyle.fade200))
            } else {
                Group {
                    header
                    reviewList
                    footer
                }
                .transition(.opacity.animation(CleanUpStyle.fade150))
            }
        }
        .padding(.horizontal, layout == .popover ? 12 : 0)
        .padding(.top, layout == .popover ? 10 : 4)
        .padding(.bottom, layout == .popover ? 10 : 0)
        .frame(maxWidth: layout == .popover ? CleanUpStyle.popoverWidth : .infinity, alignment: .leading)
        .background(ReviewKeyCatcher(
            onReturn: { cleanUp.handleReturn() },
            onEscape: { cleanUp.handleEscape() },
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
        case .done:
            return CleanUpCopy.allClear
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .leading) {
                if let armed = cleanUp.armedApp {
                    Text(CleanUpCopy.armedHint(armed.name))
                        .id("armed-\(armed.id)")
                        .transition(.opacity)
                } else {
                    Text(CleanUpCopy.leftoverHeadline(count: cleanUp.leftoverCount, dockName: cleanUp.currentDockName))
                        .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                        .id("count")
                        .transition(.opacity)
                }
            }
            .font(.system(size: layout == .popover ? 13 : 15, weight: .semibold))
            .lineLimit(1)
            .animation(CleanUpStyle.fade150, value: cleanUp.armedID)
            .animation(reduceMotion ? nil : CleanUpStyle.rowReflow, value: cleanUp.leftoverCount)

            Text(CleanUpCopy.reviewFootnote)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
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
                            quitState: cleanUp.quitState(app.id),
                            isFocused: cleanUp.focusedIndex == index,
                            isArmed: cleanUp.armedID == app.id,
                            nudgeToken: cleanUp.nudge?.id == app.id ? cleanUp.nudge?.token : nil,
                            onToggle: { cleanUp.toggleChecked(app.id) },
                            onQuit: { cleanUp.quit(app) },
                            onKeep: { cleanUp.toggleKeep(app) },
                            onShow: { cleanUp.showWaiting(app) }
                        )
                        .id(app.id)
                        .simultaneousGesture(TapGesture().onEnded {
                            cleanUp.focusedIndex = index
                        })
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .scale(scale: 0.97))
                        ))
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

    private var footer: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            Button("Cancel") { cleanUp.cancelReview() }
                .buttonStyle(CleanUpSecondaryButtonStyle())
                .accessibilityLabel("Cancel Clean Up")
            HoldToQuitAllButton(
                title: cleanUp.isQuittingAll
                    ? CleanUpCopy.quittingTitle(cleanUp.quittingApps.count)
                    : CleanUpCopy.holdToQuitTitle(cleanUp.selectedCount),
                isEnabled: cleanUp.selectedCount > 0 && !cleanUp.isQuittingAll,
                accessibilityHint: "Hold to ask the checked apps to quit. Docksly never force quits.",
                onPressingChanged: { _ in },
                onComplete: { cleanUp.quitAll(fromStrip: false) }
            )
        }
    }
}

struct CleanUpAppRow: View {
    var app: CleanUpApp
    var layout: CleanUpReviewLayout
    var isChecked: Bool
    var isKeeping: Bool
    var quitState: CleanUpQuitState?
    var isFocused: Bool
    var isArmed: Bool
    var nudgeToken: Int?
    var onToggle: () -> Void
    var onQuit: () -> Void
    var onKeep: () -> Void
    var onShow: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    @State private var isHolding = false
    @State private var nudgeOffset: CGFloat = 0

    private var isBusy: Bool { quitState == .quitting || quitState == .next }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                CleanUpCheckboxMark(isOn: isChecked)
            }
            .buttonStyle(.plain)
            .disabled(isKeeping)
            .opacity(isKeeping ? 0.4 : (isBusy ? 0.6 : 1))
            .accessibilityLabel(app.name)
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(isKeeping ? "" : "Toggles whether Quit all quits this app")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Quit \(app.name)", onQuit)
            .accessibilityAction(named: isKeeping ? "Stop Keeping \(app.name) Open" : "Always Keep \(app.name) Open", onKeep)

            CleanUpAppIcon(app: app)
                .opacity(isBusy ? 0.5 : 1)

            Text(app.name)
                .font(.system(size: 13))
                .foregroundStyle(isKeeping || isBusy ? Color.secondary : Color.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing
                .animation(CleanUpStyle.fade150, value: quitState)
        }
        .padding(.horizontal, 4)
        .frame(height: CleanUpStyle.reviewRowHeight)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(rowTint)
                .animation(quitState == .waiting ? CleanUpStyle.fade200 : .easeOut(duration: 0.12), value: rowTint)
        }
        .offset(x: nudgeOffset)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering }
        }
        .onChange(of: nudgeToken) { token in
            guard token != nil else { return }
            CleanUpNudgeRunner.run(offset: $nudgeOffset, amplitude: 4, reduceMotion: reduceMotion)
        }
        .contextMenu {
            Button("Quit \(app.name)", action: onQuit)
                .disabled(isBusy || isKeeping)
            Button(isKeeping ? "Stop Keeping \(app.name) Open" : "Always Keep \(app.name) Open", action: onKeep)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if isKeeping {
            Text("Keeping")
                .font(.system(size: 11))
                .foregroundStyle(CleanUpStyle.amber)
                .lineLimit(1)
                .transition(.opacity)
        } else if quitState == .quitting {
            HStack(spacing: 6) {
                CleanUpDelayedSpinner()
                Text("Quitting…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .transition(.opacity)
        } else if quitState == .next {
            HStack(spacing: 6) {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 10, height: 10)
                Text("Next")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .transition(.opacity)
        } else if quitState == .waiting {
            HStack(spacing: 6) {
                Text("Waiting to save")
                    .font(.system(size: 11))
                    .foregroundStyle(CleanUpStyle.amber)
                    .lineLimit(1)
                Button("Show", action: onShow)
                    .buttonStyle(CleanUpPillButtonStyle())
                    .accessibilityLabel("Show \(app.name)")
                    .accessibilityHint("Brings the app forward so you can save or quit it")
            }
            .transition(.opacity)
        } else if isHovering || isHolding || isArmed {
            HoldToQuitPill(
                title: isArmed ? "Return to Quit" : "Hold to Quit",
                onPressingChanged: { isHolding = $0 },
                onComplete: onQuit
            )
            .transition(.opacity)
        } else if !isChecked, layout == .editor {
            Text("This time only")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .transition(.opacity)
        }
    }

    private var rowTint: Color {
        if quitState == .waiting { return CleanUpStyle.amber.opacity(0.08) }
        if isHovering || isFocused { return Color.primary.opacity(0.06) }
        return .clear
    }

    private var accessibilityValue: String {
        if isKeeping { return "Keeping" }
        switch quitState {
        case .quitting, .next:
            return "Quitting"
        case .waiting:
            return "Waiting to save"
        case nil:
            return isChecked ? "Selected" : "Not selected"
        }
    }
}

/// The small red-fill pill in a review row. A 600 ms hold quits the app.
struct HoldToQuitPill: View {
    var title: String
    var onPressingChanged: (Bool) -> Void
    var onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var isPressing = false

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: CleanUpStyle.pillHeight)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.1))
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Rectangle()
                                .fill(Color.red.opacity(0.6))
                                .frame(width: proxy.size.width * progress)
                        }
                    }
                    .clipShape(Capsule(style: .continuous))
            }
            .scaleEffect(isPressing && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isPressing)
            .holdToConfirm(duration: CleanUpStyle.rowHold, progress: $progress, isPressing: $isPressing, onComplete: onComplete)
            .onChange(of: isPressing) { onPressingChanged($0) }
            .help("Hold to quit")
            .accessibilityHidden(true)
    }
}

/// The footer and strip button. A 900 ms hold quits every app it names.
struct HoldToQuitAllButton: View {
    var title: String
    var isEnabled: Bool
    var accessibilityHint: String
    var onPressingChanged: (Bool) -> Void
    var onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var isPressing = false

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 12)
            .frame(height: CleanUpStyle.footerButtonHeight)
            .background {
                RoundedRectangle(cornerRadius: CleanUpStyle.footerButtonCorner, style: .continuous)
                    .fill(Color.accentColor.opacity(isPressing ? 0.5 : 1))
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: proxy.size.width * progress)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: CleanUpStyle.footerButtonCorner, style: .continuous))
            }
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(isPressing && !reduceMotion ? DockslyStyle.pressScale : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isPressing)
            .holdToConfirm(
                duration: CleanUpStyle.allHold,
                isEnabled: isEnabled,
                progress: $progress,
                isPressing: $isPressing,
                onComplete: onComplete
            )
            .onChange(of: isPressing) { onPressingChanged($0) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityHint(accessibilityHint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                if isEnabled { onComplete() }
            }
    }
}

private struct HoldToConfirmModifier: ViewModifier {
    var duration: Double
    var isEnabled: Bool
    @Binding var progress: CGFloat
    @Binding var isPressing: Bool
    var onComplete: () -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.onLongPressGesture(
                minimumDuration: duration,
                maximumDistance: CleanUpStyle.holdMaxDistance,
                perform: {
                    CleanUpHaptics.complete()
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        progress = 0
                        isPressing = false
                    }
                    onComplete()
                },
                onPressingChanged: { down in
                    isPressing = down
                    if down {
                        CleanUpHaptics.press()
                        withAnimation(.linear(duration: duration)) { progress = 1 }
                    } else {
                        withAnimation(CleanUpStyle.holdDrain) { progress = 0 }
                    }
                }
            )
        } else {
            content
        }
    }
}

extension View {
    /// Press and hold for `duration` to confirm. The fill is linear, so the time is honest.
    /// Letting go early drains it in 150 ms, and nothing happens.
    func holdToConfirm(
        duration: Double,
        isEnabled: Bool = true,
        progress: Binding<CGFloat>,
        isPressing: Binding<Bool>,
        onComplete: @escaping () -> Void
    ) -> some View {
        modifier(HoldToConfirmModifier(
            duration: duration,
            isEnabled: isEnabled,
            progress: progress,
            isPressing: isPressing,
            onComplete: onComplete
        ))
    }
}

/// One small two-swing nudge: out, then an under-damped spring back to rest.
enum CleanUpNudgeRunner {
    @MainActor
    static func run(offset: Binding<CGFloat>, amplitude: CGFloat, reduceMotion: Bool) {
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.06)) { offset.wrappedValue = -amplitude }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(CleanUpStyle.nudgeSpring) { offset.wrappedValue = 0 }
        }
    }
}

/// Shows a spinner only after 150 ms, so a fast quit never flashes it.
struct CleanUpDelayedSpinner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        ZStack {
            if isVisible {
                if reduceMotion {
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                } else {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
        }
        .frame(width: 12, height: 12)
        .task {
            try? await Task.sleep(nanoseconds: UInt64(CleanUpStyle.spinnerDelay * 1_000_000_000))
            withAnimation(CleanUpStyle.fade150) { isVisible = true }
        }
        .accessibilityHidden(true)
    }
}

struct CleanUpAllClearView: View {
    var layout: CleanUpReviewLayout
    @EnvironmentObject private var cleanUp: CleanUpController

    var body: some View {
        VStack(spacing: 8) {
            CleanUpCheckBadge(size: 28)
                .padding(.top, 8)
            Text(CleanUpCopy.allClear)
                .font(.system(size: layout == .popover ? 15 : 17, weight: .semibold))
            Text(CleanUpCopy.allClearDetail(
                dockName: cleanUp.currentDockName,
                kept: cleanUp.selection.keeping.map(\.name)
            ))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer(minLength: 0)
                Button("Done") { cleanUp.cancelReview() }
                    .buttonStyle(CleanUpPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

/// Green check that pops in once: scale 0.9 to 1 with one small bounce.
struct CleanUpCheckBadge: View {
    var size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .scaleEffect(isShown || reduceMotion ? 1 : 0.9)
        .opacity(isShown ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion ? CleanUpStyle.fade150 : CleanUpStyle.checkPop) {
                isShown = true
            }
        }
        .accessibilityHidden(true)
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
        .animation(CleanUpStyle.fade150, value: isOn)
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

// MARK: - Editor strip

struct CleanUpStripView: View {
    @EnvironmentObject private var cleanUp: CleanUpController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredID: String?
    @State private var holdingID: String?
    @State private var isHoldingAll = false
    @FocusState private var focusedID: String?

    var body: some View {
        ZStack {
            if cleanUp.stripAllClear {
                allClear
                    .transition(.opacity.animation(CleanUpStyle.fade200))
            } else {
                strip
                    .transition(.opacity.animation(CleanUpStyle.fade200))
            }
        }
        .padding(.horizontal, DockslyStyle.contentLeading)
        .padding(.trailing, DockslyStyle.trailingInset)
        .frame(height: CleanUpStyle.stripHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(CleanUpCopy.leftoverHeadline(count: cleanUp.leftoverCount, dockName: cleanUp.currentDockName))
    }

    private var apps: [CleanUpApp] {
        Array(cleanUp.selection.leftover.prefix(CleanUpStyle.stripMaxIcons))
    }

    private var strip: some View {
        HStack(spacing: 10) {
            headline
                .frame(width: CleanUpStyle.stripHeadlineWidth, alignment: .leading)

            icons

            Spacer(minLength: 8)

            HoldToQuitAllButton(
                title: "Hold to Quit All",
                isEnabled: cleanUp.leftoverCount > 0 && !cleanUp.isQuittingAll,
                accessibilityHint: "Hold to ask every app in this strip to quit. Docksly never force quits.",
                onPressingChanged: { isHoldingAll = $0 },
                onComplete: { cleanUp.quitAll(fromStrip: true) }
            )
        }
        .background {
            // Return arms the focused icon, then quits it. Esc disarms.
            Button("") {
                if let id = focusedID, let app = apps.first(where: { $0.id == id }) {
                    cleanUp.pressReturn(on: app)
                }
            }
            .keyboardShortcut(.return, modifiers: [])
            .disabled(focusedID == nil)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    private var allClear: some View {
        HStack(spacing: 8) {
            CleanUpCheckBadge(size: 18)
            Text("\(CleanUpCopy.allClear). \(CleanUpCopy.allClearDetail(dockName: cleanUp.currentDockName, kept: []))")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Done") { cleanUp.dismissStripAllClear() }
                .buttonStyle(CleanUpSecondaryButtonStyle())
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Headline

    private enum HeadlineKind: Hashable {
        case armed(String)
        case holdingAll(Int)
        case holding(String)
        case hover(String)
        case kept(String)
        case asking(String)
        case waiting(String)
        case count
    }

    private var headlineKind: HeadlineKind {
        if let armed = cleanUp.armedID, let app = apps.first(where: { $0.id == armed }) {
            return .armed(app.name)
        }
        if isHoldingAll { return .holdingAll(cleanUp.leftoverCount) }
        if let id = holdingID, let app = apps.first(where: { $0.id == id }) {
            return .holding(app.name)
        }
        if let id = hoveredID, let app = apps.first(where: { $0.id == id }),
           cleanUp.quitState(id) == nil {
            return .hover(app.name)
        }
        if let kept = cleanUp.keptNotice { return .kept(kept.name) }
        let quitting = cleanUp.quittingApps
        if quitting.count == 1 { return .asking(CleanUpCopy.askingApp(quitting[0].name)) }
        if quitting.count > 1 { return .asking(CleanUpCopy.asking(quitting.count)) }
        let waiting = cleanUp.waitingApps
        if !waiting.isEmpty { return .waiting(CleanUpCopy.waitingMessage(names: waiting.map(\.name))) }
        return .count
    }

    private var headline: some View {
        let kind = headlineKind
        return ZStack(alignment: .leading) {
            Group {
                switch kind {
                case .armed(let name):
                    Text(CleanUpCopy.armedHint(name))
                case .holdingAll(let count):
                    Text(CleanUpCopy.holdingAllHint(count))
                        .foregroundStyle(.secondary)
                case .holding(let name):
                    Text(CleanUpCopy.holdingHint(name))
                        .foregroundStyle(.secondary)
                case .hover(let name):
                    Text(CleanUpCopy.hoverHint(name))
                        .foregroundStyle(.secondary)
                case .kept(let name):
                    HStack(spacing: 8) {
                        Text(CleanUpCopy.keptNotice(name))
                            .foregroundStyle(.secondary)
                        Button("Undo") { cleanUp.undoKeep() }
                            .buttonStyle(CleanUpPillButtonStyle())
                            .accessibilityLabel("Undo Always Keep \(name)")
                    }
                case .asking(let text):
                    Text(text)
                        .foregroundStyle(.secondary)
                case .waiting(let text):
                    HStack(spacing: 8) {
                        Text(text)
                            .foregroundStyle(CleanUpStyle.amber)
                        if let first = cleanUp.waitingApps.first {
                            Button("Show") { cleanUp.showWaiting(first) }
                                .buttonStyle(CleanUpPillButtonStyle())
                                .accessibilityLabel("Show \(first.name)")
                        }
                    }
                case .count:
                    Text(CleanUpCopy.leftoverHeadline(count: cleanUp.leftoverCount, dockName: cleanUp.currentDockName))
                        .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                        .animation(reduceMotion ? nil : CleanUpStyle.stripSlide, value: cleanUp.leftoverCount)
                }
            }
            .id(kind)
            .transition(.opacity)
        }
        .font(.system(size: 13, weight: .medium))
        .lineLimit(1)
        .truncationMode(.tail)
        .animation(CleanUpStyle.fade150, value: kind)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: Icons

    private var icons: some View {
        let shown = apps
        let overflow = cleanUp.leftoverCount - shown.count
        return HStack(spacing: CleanUpStyle.stripIconGap) {
            ForEach(shown) { app in
                CleanUpStripIcon(
                    app: app,
                    quitState: cleanUp.quitState(app.id),
                    isArmed: cleanUp.armedID == app.id,
                    isFocused: focusedID == app.id,
                    nudgeToken: cleanUp.nudge?.id == app.id ? cleanUp.nudge?.token : nil,
                    onHover: { hovering in
                        if hovering {
                            hoveredID = app.id
                        } else if hoveredID == app.id {
                            hoveredID = nil
                        }
                    },
                    onHoldChanged: { holding in
                        if holding {
                            holdingID = app.id
                        } else if holdingID == app.id {
                            holdingID = nil
                        }
                    },
                    onQuit: { cleanUp.quit(app, fromStrip: true) },
                    onKeep: { cleanUp.alwaysKeep(app, fromStrip: true) },
                    onCleanUpNow: { cleanUp.beginReview() }
                )
                .focusable()
                .focused($focusedID, equals: app.id)
                .transition(reduceMotion
                    ? .opacity.animation(CleanUpStyle.fade150)
                    : .scale(scale: 0.7).combined(with: .opacity).animation(.easeOut(duration: 0.18)))
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(overflow) more")
            }
        }
        .animation(reduceMotion ? nil : CleanUpStyle.stripSlide, value: shown.map(\.id))
        .onMoveCommand { direction in
            moveFocus(direction, in: shown)
        }
        .onExitCommand {
            cleanUp.disarm()
        }
    }

    private func moveFocus(_ direction: MoveCommandDirection, in shown: [CleanUpApp]) {
        guard !shown.isEmpty else { return }
        let index = shown.firstIndex { $0.id == focusedID } ?? 0
        switch direction {
        case .left:
            focusedID = shown[max(index - 1, 0)].id
        case .right:
            focusedID = shown[min(index + 1, shown.count - 1)].id
        default:
            return
        }
        cleanUp.disarm()
    }
}

/// One leftover icon in the editor strip. A 600 ms hold fills a red ring and quits it.
struct CleanUpStripIcon: View {
    var app: CleanUpApp
    var quitState: CleanUpQuitState?
    var isArmed: Bool
    var isFocused: Bool
    var nudgeToken: Int?
    var onHover: (Bool) -> Void
    var onHoldChanged: (Bool) -> Void
    var onQuit: () -> Void
    var onKeep: () -> Void
    var onCleanUpNow: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    @State private var isPressing = false
    @State private var progress: CGFloat = 0
    @State private var nudgeOffset: CGFloat = 0

    private static let ringSize = CleanUpStyle.stripIconSize + 8
    private static let ringWidth: CGFloat = 2.4

    private var isBusy: Bool { quitState == .quitting || quitState == .next }

    var body: some View {
        ZStack {
            ring
            CleanUpAppIcon(app: app, size: CleanUpStyle.stripIconSize)
                .opacity(isBusy ? 0.5 : 1)
                .animation(CleanUpStyle.fade150, value: isBusy)
        }
        .frame(width: Self.ringSize, height: Self.ringSize)
        .overlay(alignment: .topTrailing) {
            if quitState == .waiting {
                waitingBadge
                    .offset(x: 3, y: -3)
                    .transition(.opacity.animation(CleanUpStyle.fade200))
            }
        }
        .overlay(alignment: .top) {
            if isHovering, !isBusy {
                tooltip
                    .fixedSize()
                    .offset(y: -26)
                    .transition(.opacity.animation(CleanUpStyle.fade150))
                    .allowsHitTesting(false)
            }
        }
        .scaleEffect(isPressing && !reduceMotion ? 0.96 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isPressing)
        .offset(x: nudgeOffset)
        .contentShape(Circle())
        .onHover { hovering in
            withAnimation(CleanUpStyle.fade150) { isHovering = hovering }
            onHover(hovering)
        }
        .holdToConfirm(
            duration: CleanUpStyle.rowHold,
            isEnabled: !isBusy,
            progress: $progress,
            isPressing: $isPressing,
            onComplete: onQuit
        )
        .onChange(of: isPressing) { onHoldChanged($0) }
        .onChange(of: nudgeToken) { token in
            guard token != nil else { return }
            CleanUpNudgeRunner.run(offset: $nudgeOffset, amplitude: 3, reduceMotion: reduceMotion)
        }
        .contextMenu {
            Button("Quit \(app.name)", action: onQuit)
                .disabled(isBusy)
            Button("Always Keep \(app.name) Open", action: onKeep)
            Divider()
            Button("Clean Up Now…", action: onCleanUpNow)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(app.name)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Hold to quit. Or press Return twice.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Quit \(app.name)", onQuit)
        .accessibilityAction(named: "Always Keep \(app.name) Open", onKeep)
    }

    @ViewBuilder
    private var ring: some View {
        let track = colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.15)
        ZStack {
            if quitState == .waiting {
                Circle()
                    .stroke(CleanUpStyle.amber, lineWidth: Self.ringWidth)
                    .transition(.opacity.animation(CleanUpStyle.fade200))
            } else if isBusy {
                CleanUpSpinnerRing(lineWidth: Self.ringWidth, track: track)
                    .transition(.opacity.animation(CleanUpStyle.fade150))
            } else {
                Circle()
                    .stroke(track, lineWidth: Self.ringWidth)
                    .opacity(isHovering || isPressing || isArmed || isFocused ? 1 : 0)
                    .animation(CleanUpStyle.fade150, value: isHovering)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            if isFocused {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
                    .padding(-3)
            }
        }
        .frame(width: Self.ringSize - Self.ringWidth, height: Self.ringSize - Self.ringWidth)
    }

    private var waitingBadge: some View {
        ZStack {
            Circle().fill(CleanUpStyle.amber)
            Text("!")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(.black)
        }
        .frame(width: 11, height: 11)
        .accessibilityHidden(true)
    }

    private var tooltip: some View {
        Text(app.name)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(white: 0.2))
            )
            .accessibilityHidden(true)
    }

    private var accessibilityValue: String {
        switch quitState {
        case .quitting, .next:
            return "Quitting"
        case .waiting:
            return "Waiting to save"
        case nil:
            return isArmed ? "Press Return again to quit" : "Running, not in this dock"
        }
    }
}

/// The ring that turns while an app answers. Reduce Motion keeps it still.
struct CleanUpSpinnerRing: View {
    var lineWidth: CGFloat
    var track: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var isSpinning = false

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            if isVisible {
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(isSpinning ? 270 : -90))
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: UInt64(CleanUpStyle.spinnerDelay * 1_000_000_000))
            withAnimation(CleanUpStyle.fade150) { isVisible = true }
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                isSpinning = true
            }
        }
    }
}

// MARK: - Buttons

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

/// Small round pill for Show and Undo.
struct CleanUpPillButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.14 : 0.08))
            )
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.92 : 1))
            .animation(reduceMotion ? nil : DockslyStyle.pressSpring, value: configuration.isPressed)
    }
}

// MARK: - Keys and window height

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
            // Ignore key repeat, so holding Return does not arm and quit at once.
            if !event.isARepeat { handlers?.onReturn() }
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
        // SwiftUI lays out below the hidden title bar, so add that strip to the SwiftUI height.
        let titlebarInset = max(0, contentRect.height - window.contentLayoutRect.height)
        let height = height + titlebarInset
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
