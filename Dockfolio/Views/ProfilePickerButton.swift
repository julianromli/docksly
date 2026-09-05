import SwiftUI

struct ProfilePickerButton: View {
    @EnvironmentObject private var store: DockStore
    @State private var newName = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        Menu {
            ForEach(store.library.profiles) { profile in
                Button {
                    store.select(profileID: profile.id)
                } label: {
                    Text("\(store.library.activeProfileID == profile.id ? "✓ " : "")\(profile.name)")
                }
            }
            Divider()
            Button("New Dock…") {
                store.wantsNewDockName = true
            }
            Button("Delete Dock…", role: .destructive) {
                showDeleteConfirm = true
            }
            .disabled(store.library.profiles.count < 2)
        } label: {
            HStack(spacing: 8) {
                ColorDot(color: store.draftColor.color, diameter: 9)
                Text(store.draftName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
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
        .alert("Delete this dock?", isPresented: $showDeleteConfirm) {
            Button("Delete Dock", role: .destructive) {
                store.deleteSelectedDock()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(store.draftName)” will be removed from this Mac. The real Dock does not change until you apply another setup.")
        }
    }
}

struct ProfileIdentityEditor: View {
    @EnvironmentObject private var store: DockStore
    @State private var showColors = false
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
            .buttonStyle(.plain)
            .help("Change dock color")
            .accessibilityLabel("Dock color")
            .popover(isPresented: $showColors, arrowEdge: .bottom) {
                colorSwatches
                    .padding(10)
            }

            TextField("Dock name", text: Binding(
                get: { store.draftName },
                set: { store.renameDraft($0) }
            ))
            .textFieldStyle(.plain)
            .font(.title2.weight(.semibold))
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
                Button {
                    store.setDraftColor(color)
                    showColors = false
                } label: {
                    ZStack {
                        ColorDot(color: color.color, diameter: 20)
                        if store.draftColor == color {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(color.displayName)
                .accessibilityLabel(color.displayName)
                .accessibilityAddTraits(store.draftColor == color ? .isSelected : [])
            }
        }
    }
}

