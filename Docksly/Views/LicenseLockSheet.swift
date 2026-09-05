import SwiftUI

struct LicenseLockSheet: View {
    @EnvironmentObject private var license: LicenseStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Trial ended")
                    .font(.title3.weight(.semibold))
                Text("Enter a license key to save docks, apply a dock, or change a layout. Settings stays available.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LicenseActivationForm()
        }
        .padding(24)
        .frame(width: 400)
        .interactiveDismissDisabled(true)
    }
}

struct LicenseActivationForm: View {
    @EnvironmentObject private var license: LicenseStore
    @State private var licenseCode = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if license.isLicensed {
                Text("This Mac is unlocked with a lifetime license.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("License key")
                        .font(.callout)
                    TextField("Paste your license key", text: $licenseCode)
                        .textFieldStyle(.roundedBorder)
                        .disabled(license.isActivating)
                }
                HStack(spacing: 8) {
                    Button("Activate") {
                        Task { await license.activate(code: licenseCode) }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(cannotActivate)

                    Button("Buy License") {
                        license.openCheckout()
                    }
                    .disabled(license.isActivating || LicenseConfig.checkoutURL == nil)

                    if license.isActivating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .controlSize(.small)
                    }
                }
                if LicenseConfig.checkoutURL == nil || LicenseConfig.apiURL == nil {
                    Text("Set DockslyCheckoutURL and DockslyLicenseAPIURL in Info.plist before you activate a key.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let lastError = license.lastError {
                Text(lastError)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            if !license.record.licenseCode.isEmpty, licenseCode.isEmpty {
                licenseCode = license.record.licenseCode
            }
        }
    }

    private var cannotActivate: Bool {
        license.isActivating
            || licenseCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || LicenseConfig.apiURL == nil
    }
}
