import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AddAppSheet: View {
    @EnvironmentObject private var store: DockStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var apps: [InstalledApp] = []
    @State private var isLoading = true
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Add Application")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Browse…", action: browse)
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            TextField("Search applications", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)

            Group {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Reading Applications folders…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? "No applications found. Use Browse to pick a bundle."
                         : "No applications match “\(query)”. Use Browse to pick a bundle.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filtered) { app in
                        Button {
                            if store.addApplication(path: app.path) {
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(nsImage: AppIconService.shared.icon(forAppAt: app.path))
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                Text(app.name)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(minHeight: 320)
        }
        .padding(20)
        .frame(width: 460, height: 500)
        .onAppear { searchFocused = true }
        .task {
            apps = await InstalledAppScanner.scan()
            isLoading = false
        }
    }

    private var filtered: [InstalledApp] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return apps }
        return apps.filter { app in
            app.name.localizedCaseInsensitiveContains(trimmed)
                || (app.bundleIdentifier?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.title = "Choose an application"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if store.addApplication(path: url.path) {
                dismiss()
            }
        }
    }
}
