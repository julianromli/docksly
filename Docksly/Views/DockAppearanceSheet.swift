import SwiftUI

/// Per-dock Dock settings. Off by default. When off, Docksly leaves the Dock settings alone.
struct DockAppearanceSheet: View {
    @EnvironmentObject private var store: DockStore
    @Environment(\.dismiss) private var dismiss

    /// The settings being edited. Starts from the dock, or from the live Dock when the dock has none.
    @State private var value = DockAppearance.systemDefault

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Dock Appearance")
                    .font(.headline)
                Text("“\(store.draftName)” can carry its own Dock settings. When this is off, Docksly does not change them.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding([.horizontal, .top], 20)

            Form {
                Toggle("Use these Dock settings", isOn: $value.isEnabled)

                Group {
                    LabeledContent("Size") {
                        Slider(value: $value.tileSize, in: DockAppearance.sizeRange) {
                            EmptyView()
                        } minimumValueLabel: {
                            Text("Small")
                        } maximumValueLabel: {
                            Text("Large")
                        }
                    }
                    Toggle("Magnification", isOn: $value.magnification)
                    LabeledContent("Magnified size") {
                        Slider(value: $value.largeSize, in: DockAppearance.sizeRange) {
                            EmptyView()
                        } minimumValueLabel: {
                            Text("Small")
                        } maximumValueLabel: {
                            Text("Large")
                        }
                    }
                    .disabled(!value.magnification)
                    Picker("Position on screen", selection: $value.position) {
                        ForEach(DockAppearance.Position.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Automatically hide and show the Dock", isOn: $value.autohide)
                    Toggle("Show suggested and recent apps in Dock", isOn: $value.showRecents)
                }
                .disabled(!value.isEnabled)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Copy from Current Dock") {
                    var live = DockApplicator.readAppearance()
                    live.isEnabled = true
                    value = live
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Done") {
                    // A dock with no settings stays that way when the toggle is still off.
                    let keepsNone = store.draftAppearance == nil && !value.isEnabled
                    store.setDraftAppearance(keepsNone ? nil : value)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 20)
            .padding(.top, 4)

            Text("Press Save Changes or Use This Dock to apply.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 460)
        .onAppear {
            if let saved = store.draftAppearance {
                value = saved
            } else {
                var live = DockApplicator.readAppearance()
                live.isEnabled = false
                value = live
            }
        }
    }
}
