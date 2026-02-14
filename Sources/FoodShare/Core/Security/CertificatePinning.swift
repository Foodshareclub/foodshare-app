//
//  CertificatePinning.swift
//  Foodshare
//
//  SSL Certificate Pinning for Supabase connections
//  Uses public key pinning for resilience against certificate rotation
//
//  References:
//  - https://www.netguru.com/blog/certificate-pinning-in-ios
//  - https://medium.com/@ahmed.elmemy21/implementing-certificate-pinning-in-ios-enhancing-app-security-fec46a0df676
//

import CommonCrypto
import Foundation
import OSLog
#if !SKIP
import Security
#endif

// MARK: - Certificate Pinning Error

/// Errors that can occur during SSL certificate pinning validation.
///
/// Thread-safe for Swift 6 concurrency.
enum CertificatePinningError: LocalizedError, Sendable {
    /// No certificate found in server response
    case noCertificateFound
    /// Certificate is malformed or cannot be parsed
    case invalidCertificate
    /// Server public key doesn't match pinned keys
    case publicKeyMismatch
    /// General pinning validation failure
    case pinningValidationFailed(String)

    var errorDescription: String? {
        switch self {
        case .noCertificateFound:
            "No server certificate found in the authentication challenge"
        case .invalidCertificate:
            "Server certificate is invalid or could not be parsed"
        case .publicKeyMismatch:
            "Server public key does not match pinned keys"
        case let .pinningValidationFailed(message):
            "Certificate pinning validation failed: \(message)"
        }
    }
}

// MARK: - Certificate Pinning Manager

/// Manages SSL certificate pinning for secure network connections
/// Uses public key pinning (more resilient to certificate rotation than certificate pinning)
final class CertificatePinningManager: NSObject, @unchecked Sendable {
    static let shared = CertificatePinningManager()

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "CertificatePinning")

    // MARK: - Pinned Public Key Hashes (SHA-256)

    /// Pinned public key hashes for Supabase domains
    /// These are SHA-256 hashes of the Subject Public Key Info (SPKI)
    ///
    /// To generate pins from a certificate chain, run:
    /// ```bash
    /// openssl s_client -connect <project>.supabase.co:443 -servername <project>.supabase.co 2>/dev/null | \
    ///   openssl x509 -pubkey -noout | \
    ///   openssl pkey -pubin -outform DER | \
    ///   openssl dgst -sha256 -binary | base64
    /// ```
    ///
    /// For the full chain (recommended), extract each certificate and generate pins.
    /// Include at least the leaf certificate and one backup (intermediate or root CA).
    // Pin disabled: Cloudflare handles TLS for api.foodshare.club and rotates certs frequently
    private let pinnedDomains: [String: Set<String>] = [:]

    /// Backend domain suffix for wildcard matching
    private let supabaseDomainSuffix = ".foodshare.club"

    /// Get the configured Supabase host from AppEnvironment
    private var configuredSupabaseHost: String? {
        guard let urlString = AppEnvironment.supabaseURL,
              let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }
        return host
    }

    /// Domains that should always be allowed (e.g., for development)
    private let allowedDomains: Set<String> = [
        "localhost",
        "127.0.0.1"
    ]

    /// Whether pinning is enabled (disable for debug builds if needed)
    var isPinningEnabled: Bool {
        #if DEBUG
            // Allow disabling pinning in debug builds via environment variable
            return ProcessInfo.processInfo.environment["DISABLE_CERTIFICATE_PINNING"] == nil
        #else
            return true
        #endif
    }

    override private init() {
        super.init()
        logger.info("CertificatePinningManager initialized, pinning enabled: \(self.isPinningEnabled)")
    }

    // MARK: - Validation

    /// Validates the server trust against pinned public keys
    /// - Parameters:
    ///   - serverTrust: The server's trust object from the authentication challenge
    ///   - host: The host being connected to
    /// - Returns: True if the server's public key matches a pinned key
    func validateServerTrust(_ serverTrust: SecTrust, forHost host: String) -> Bool {
        // Skip validation if pinning is disabled
        guard isPinningEnabled else {
            logger.debug("Certificate pinning disabled, allowing connection to: \(host)")
            return true
        }

        // Allow localhost and development domains
        if allowedDomains.contains(host) {
            logger.debug("Allowing connection to development domain: \(host)")
            return true
        }

        // Get pins for this specific domain or check if it's a Supabase domain
        let pins = getPinsForHost(host)

        // If no pins configured, check if this is a Supabase domain that should be pinned
        guard !pins.isEmpty else {
            if isSupabaseDomain(host) {
                // Supabase domain without pins - this is a configuration issue
                // In production, you should have pins configured
                #if DEBUG
                    logger.warning("No certificate pins configured for Supabase host: \(host) - allowing in DEBUG")
                    return true
                #else
                    logger.error("No certificate pins configured for Supabase host: \(host) - blocking in RELEASE")
                    // For enterprise security, block unpinned Supabase connections in release
                    return false
                #endif
            }
            // Non-Supabase domain without pins - allow (default networking behavior)
            logger.debug("No pins configured for non-Supabase host: \(host) - allowing")
            return true
        }

        // Get the certificate chain
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              !certificateChain.isEmpty else {
            logger.error("Failed to get certificate chain for host: \(host)")
            return false
        }

        // Validate each certificate in the chain against our pins
        for certificate in certificateChain {
            if let publicKeyHash = extractPublicKeyHash(from: certificate) {
                if pins.contains(publicKeyHash) {
                    logger.info("Certificate pinning validation successful for host: \(host)")
                    return true
                }
                // Log the hash for debugging/pin extraction (only in debug)
                #if DEBUG
                    logger.debug("Certificate hash not in pins: \(publicKeyHash)")
                #endif
            }
        }

        logger.error("Certificate pinning validation FAILED for host: \(host)")
        return false
    }

    /// Gets pins for a specific host, checking both exact matches and the configured Supabase host
    private func getPinsForHost(_ host: String) -> Set<String> {
        // Check exact match first
        if let pins = pinnedDomains[host] {
            return pins
        }

        // Check if this is the configured Supabase host
        if let configuredHost = configuredSupabaseHost,
           host == configuredHost,
           let pins = pinnedDomains[configuredHost] {
            return pins
        }

        return []
    }

    /// Checks if a host is a Supabase domain
    private func isSupabaseDomain(_ host: String) -> Bool {
        host.hasSuffix(supabaseDomainSuffix)
    }

    /// Extracts the SHA-256 hash of the public key from a certificate
    private func extractPublicKeyHash(from certificate: SecCertificate) -> String? {
        // Get the public key from the certificate
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            logger.debug("Failed to extract public key from certificate")
            return nil
        }

        // Get the external representation (DER format) of the public key
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            logger
                .debug("Failed to get public key data: \(error?.takeRetainedValue().localizedDescription ?? "unknown")")
            return nil
        }

        // Hash the public key data with SHA-256
        let hash = sha256(data: publicKeyData)
        return hash.base64EncodedString()
    }

    /// Computes SHA-256 hash of data
    private func sha256(data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return Data(hash)
    }

    // MARK: - Pin Generation Helper

    /// Generates a pin hash from a certificate file (for development use)
    /// - Parameter certificatePath: Path to a .cer or .der certificate file
    /// - Returns: Base64-encoded SHA-256 hash of the public key
    func generatePinFromCertificate(at certificatePath: String) -> String? {
        guard let certificateData = FileManager.default.contents(atPath: certificatePath),
              let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
            logger.error("Failed to load certificate from path: \(certificatePath)")
            return nil
        }

        return extractPublicKeyHash(from: certificate)
    }
}

// MARK: - URLSessionDelegate Extension

extension CertificatePinningManager: URLSessionDelegate {
    /// Handles server authentication challenges with certificate pinning validation
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void,
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host

        if validateServerTrust(serverTrust, forHost: host) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            logger.error("Rejecting connection to \(host) due to certificate pinning failure")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - URLSessionTaskDelegate Extension

extension CertificatePinningManager: URLSessionTaskDelegate {
    /// Handles per-task authentication challenges
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void,
    ) {
        urlSession(session, didReceive: challenge, completionHandler: completionHandler)
    }
}
