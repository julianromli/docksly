import SwiftUI

struct ProfilePickerButton: View {
    @EnvironmentObject private var store: DockStore
    @State private var newName = ""

    var body: some View {
        Menu {
            ForEach(store.library.profiles) { profile in
                Button {
                    store.select(profileID: profile.id)
                } label: {
                    HStack {
                        if store.library.activeProfileID == profile.id {
                            Image(systemName: "checkmark")
                        }
                        Label {
                            Text(profile.name)
                        } icon: {
                            ColorDot(color: profile.color.color, diameter: 8)
                        }
                    }
                }
            }
            Divider()
            Button("New Dock…") {
                store.wantsNewDockName = true
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .accessibilityLabel("Switch Dock")
        .alert("New Dock", isPresented: $store.wantsNewDockName) {
            TextField("Name", text: $newName)
            Button("Create Dock") {
                store.createDock(named: newName)
                newName = ""
            }
            Button("Cancel", role: .cancel) {
                newName = ""
            }
        } message: {
            Text("Give this setup a name. Dockfolio copies the items you see now.")
        }
    }
}

struct ProfileIdentityEditor: View {
    @EnvironmentObject private var store: DockStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showColors = false
    @State private var allowsSwatchMotion = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button {
                showColors.toggle()
            } label: {
                ColorDot(color: store.draftColor.color, diameter: 14)
                    .frame(width: 22, height: 22)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .help("Change dock color")
            .accessibilityLabel("Dock color")
            .popover(isPresented: $showColors, arrowEdge: .bottom) {
                colorSwatches
                    .padding(10)
                    .onAppear {
                        DispatchQueue.main.async {
                            allowsSwatchMotion = true
                        }
                    }
                    .onDisappear {
                        allowsSwatchMotion = false
                    }
            }

            TextField("Dock name", text: Binding(
                get: { store.draftName },
                set: { store.renameDraft($0) }
            ))
            .textFieldStyle(.plain)
            .font(.title3.weight(.semibold))
            .tracking(-0.015)
            .frame(maxWidth: 240)
            .focused($nameFocused)
            .onSubmit { store.commitDraftName() }
            .onChange(of: nameFocused) { focused in
                if !focused { store.commitDraftName() }
            }
        }
    }

    private var colorSwatches: some View {
        HStack(spacing: 8) {
            ForEach(ProfileColor.palette) { color in
                let selected = store.draftColor == color
                Button {
                    store.setDraftColor(color)
                    showColors = false
                } label: {
                    ZStack {
                        ColorDot(color: color.color, diameter: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .contextualIconChrome(
                                visible: selected,
                                animated: allowsSwatchMotion && !reduceMotion
                            )
                    }
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())
                .help(color.displayName)
                .accessibilityLabel(color.displayName)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
