import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AddAppSheet: View {
    @EnvironmentObject private var store: DockStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var apps: [InstalledApp] = []
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Add application")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Browse…", action: browse)
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            TextField("Search applications", text: $query)
                .textFieldStyle(.roundedBorder)

            Group {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Reading Applications folders…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    Text("No applications match “\(query)”. Use Browse to pick a bundle.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filtered) { app in
                        Button {
                            store.addApplication(path: app.path)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(nsImage: AppIconService.shared.icon(forAppAt: app.path))
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name)
                                    if let bundleIdentifier = app.bundleIdentifier {
                                        Text(bundleIdentifier)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: 320)
        }
        .padding(20)
        .frame(width: 480, height: 480)
        .task {
            let scanned = InstalledAppScanner.scan()
            apps = scanned
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
            store.addApplication(path: url.path)
            dismiss()
        }
    }
}
