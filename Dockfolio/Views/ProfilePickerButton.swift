import SwiftUI

struct ProfilePickerButton: View {
    @EnvironmentObject private var store: DockStore
    @State private var showNewName = false
    @State private var newName = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        Menu {
            ForEach(store.library.profiles) { profile in
                Button {
                    store.select(profileID: profile.id)
                } label: {
                    Label {
                        Text(profile.name)
                    } icon: {
                        Image(systemName: store.library.activeProfileID == profile.id ? "checkmark" : "circle.fill")
                            .foregroundStyle(profile.color.color)
                    }
                }
            }
            Divider()
            Button("New Dock…") {
                newName = ""
                showNewName = true
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
        .alert("New Dock", isPresented: $showNewName) {
            TextField("Name", text: $newName)
            Button("Create Dock") {
                store.createDock(named: newName)
            }
            Button("Cancel", role: .cancel) {}
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

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(ProfileColor.palette) { color in
                    Button {
                        store.setDraftColor(color)
                    } label: {
                        Label {
                            Text(color.hex)
                        } icon: {
                            Image(systemName: store.draftColor == color ? "checkmark.circle.fill" : "circle.fill")
                                .foregroundStyle(color.color)
                        }
                    }
                }
            } label: {
                ColorDot(color: store.draftColor.color, diameter: 12)
                    .padding(4)
            }
            .menuStyle(.borderlessButton)
            .help("Profile color")

            TextField("Dock name", text: Binding(
                get: { store.draftName },
                set: { store.renameDraft($0) }
            ))
            .textFieldStyle(.plain)
            .font(.title2.weight(.semibold))
            .frame(maxWidth: 240)
        }
    }
}
