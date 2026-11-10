import Foundation

enum UpdateDisabledReason: Equatable {
    case build
    case readOnlyVolume
    case configuration

    var message: String {
        switch self {
        case .build: return L10n.t("UpdateStatusDisabledBuild")
        case .readOnlyVolume: return L10n.t("UpdateStatusReadOnly")
        case .configuration: return L10n.t("UpdateStatusConfiguration")
        }
    }
}

enum UpdateError: Error, Equatable, LocalizedError {
    case disabled(UpdateDisabledReason)
    case network
    case rateLimited
    case noReleases
    case invalidResponse
    case invalidRelease
    case downloadFailed
    case digestMismatch
    case signatureMismatch
    case invalidPublicKey
    case invalidSignature
    case mountFailed
    case invalidBundle
    case incompatibleSystem(String)
    case fileMissing
    case openFailed
    case cancelled
    case configuration
    case commandFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .disabled(let reason): return reason.message
        case .network: return L10n.t("UpdateErrorNetwork")
        case .rateLimited: return L10n.t("UpdateErrorRateLimited")
        case .noReleases: return L10n.t("UpdateErrorNoReleases")
        case .invalidResponse: return L10n.t("UpdateErrorInvalidResponse")
        case .invalidRelease: return L10n.t("UpdateErrorInvalidRelease")
        case .downloadFailed: return L10n.t("UpdateErrorDownloadFailed")
        case .digestMismatch: return L10n.t("UpdateErrorDigestMismatch")
        case .signatureMismatch: return L10n.t("UpdateErrorSignatureMismatch")
        case .invalidPublicKey: return L10n.t("UpdateErrorInvalidPublicKey")
        case .invalidSignature: return L10n.t("UpdateErrorInvalidSignature")
        case .mountFailed: return L10n.t("UpdateErrorMountFailed")
        case .invalidBundle: return L10n.t("UpdateErrorInvalidBundle")
        case .incompatibleSystem(let version):
            return L10n.f("UpdateErrorIncompatibleSystemFormat", version)
        case .fileMissing: return L10n.t("UpdateErrorFileMissing")
        case .openFailed: return L10n.t("UpdateErrorOpenFailed")
        case .cancelled: return L10n.t("UpdateErrorCancelled")
        case .configuration: return L10n.t("UpdateErrorConfiguration")
        case .commandFailed: return L10n.t("UpdateErrorCommandFailed")
        case .unknown: return L10n.t("UpdateErrorUnknown")
        }
    }
}

enum UpdateState: Equatable {
    case disabled(UpdateDisabledReason)
    case idle
    case checking
    case upToDate(version: String, checkedAt: Date)
    case skipped(version: String, release: UpdateRelease?)
    case available(UpdateRelease)
    case downloading(UpdateRelease, progress: Double)
    case downloaded(UpdateRelease, fileURL: URL)
    case opening(UpdateRelease, fileURL: URL)
    case failed(UpdateError, release: UpdateRelease?, manual: Bool)

    var release: UpdateRelease? {
        switch self {
        case .available(let release),
             .downloading(let release, _),
             .downloaded(let release, _),
             .opening(let release, _):
            return release
        case .skipped(_, let release):
            return release
        case .failed(_, let release, _):
            return release
        case .disabled, .idle, .checking, .upToDate:
            return nil
        }
    }

    var downloadedFileURL: URL? {
        switch self {
        case .downloaded(_, let url), .opening(_, let url):
            return url
        default:
            return nil
        }
    }

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .opening:
            return true
        default:
            return false
        }
    }

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }
}

struct MountedUpdate {
    let mountURL: URL
    let appURL: URL
}
