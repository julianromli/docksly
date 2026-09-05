import Foundation

struct LicenseVerifyResult: Equatable {
    var active: Bool
    var error: String?

    var userMessage: String {
        switch error {
        case "invalid":
            return "This license key is not valid."
        case "inactive":
            return "This license is not active."
        case "not_found":
            return "This license key was not found."
        case "limit":
            return "This license has reached its activation limit."
        case "upstream":
            return "Docksly could not reach the license service."
        default:
            return "Docksly could not verify this license key."
        }
    }
}

enum LicenseClient {
    private struct VerifyRequest: Encodable {
        let licenseCode: String
    }

    private struct VerifyResponse: Decodable {
        let active: Bool
        let error: String?
    }

    static func verify(licenseCode: String) async throws -> LicenseVerifyResult {
        guard let base = LicenseConfig.apiURL else {
            return LicenseVerifyResult(active: false, error: "upstream")
        }
        let url = base.appendingPathComponent("v1/license/verify")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONEncoder().encode(VerifyRequest(licenseCode: licenseCode))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            return LicenseVerifyResult(active: false, error: "upstream")
        }
        if http.statusCode >= 500 {
            return LicenseVerifyResult(active: false, error: "upstream")
        }

        let decoded = try JSONDecoder().decode(VerifyResponse.self, from: data)
        if decoded.active {
            return LicenseVerifyResult(active: true, error: nil)
        }
        return LicenseVerifyResult(active: false, error: decoded.error ?? "invalid")
    }
}
