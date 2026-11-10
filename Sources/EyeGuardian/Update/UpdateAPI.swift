import Foundation

protocol UpdateAPI {
    func latestRelease() async throws -> UpdateRelease
    func data(from url: URL) async throws -> Data
}

struct GitHubUpdateAPI: UpdateAPI {
    let configuration: UpdateConfiguration
    let session: URLSession

    init(configuration: UpdateConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func latestRelease() async throws -> UpdateRelease {
        var base = configuration.apiBaseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: "\(base)/repos/\(configuration.repository)/releases/latest") else {
            throw UpdateError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UpdateError.network
        }
        guard let http = response as? HTTPURLResponse else {
            throw UpdateError.invalidResponse
        }
        switch http.statusCode {
        case 200:
            break
        case 403:
            throw UpdateError.rateLimited
        case 404:
            throw UpdateError.noReleases
        default:
            throw UpdateError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let release: GitHubRelease
        do {
            release = try decoder.decode(GitHubRelease.self, from: data)
        } catch {
            throw UpdateError.invalidResponse
        }
        guard let update = UpdateRelease(githubRelease: release) else {
            throw UpdateError.invalidRelease
        }
        return update
    }

    func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw UpdateError.downloadFailed
            }
            return data
        } catch let error as UpdateError {
            throw error
        } catch {
            throw UpdateError.downloadFailed
        }
    }
}
