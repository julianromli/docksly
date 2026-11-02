import SwiftUI

/// Asks for a web address and an optional name, then adds a link tile.
struct AddLinkSheet: View {
    @EnvironmentObject private var store: DockStore
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var name = ""
    @FocusState private var addressFocused: Bool

    private var isValid: Bool {
        DockOtherItem.normalizedLinkURL(address) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Link")
                .font(.headline)
            Text("The link goes on the right side of the Dock. A click opens it in your default browser.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Web address")
                    .font(.callout)
                TextField("https://example.com", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .focused($addressFocused)
                    .autocorrectionDisabled(true)
                if !address.isEmpty && !isValid {
                    Text("Enter a full web address, for example https://example.com.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Name (optional)")
                    .font(.callout)
                TextField("Example", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add Link") {
                    if store.addLink(address, label: name) {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear { addressFocused = true }
    }
}
