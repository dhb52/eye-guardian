import Foundation

protocol UpdateDownloading: AnyObject {
    func download(_ url: URL,
                  userAgent: String,
                  progress: @escaping @MainActor (Double) -> Void) async throws -> URL
    func cancel()
}

final class URLSessionDownloader: NSObject, UpdateDownloading, URLSessionDownloadDelegate {
    private let lock = NSLock()
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var continuation: CheckedContinuation<URL, Error>?
    private var progress: (@MainActor (Double) -> Void)?
    private var didFinish = false

    func download(_ url: URL,
                  userAgent: String,
                  progress: @escaping @MainActor (Double) -> Void) async throws -> URL {
        prepareForDownload()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                self.continuation = continuation
                self.progress = progress
                lock.unlock()

                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 30
                configuration.timeoutIntervalForResource = 300
                let session = URLSession(configuration: configuration,
                                         delegate: self,
                                         delegateQueue: nil)
                lock.lock()
                self.session = session
                lock.unlock()

                var request = URLRequest(url: url)
                request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                let task = session.downloadTask(with: request)
                lock.lock()
                self.task = task
                lock.unlock()
                task.resume()
            }
        } onCancel: {
            self.cancel()
        }
    }

    private func prepareForDownload() {
        lock.lock()
        didFinish = false
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        let task = self.task
        lock.unlock()
        task?.cancel()
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("EyeGuardianUpdate-\(UUID().uuidString).dmg")
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            finish(.success(destination))
        } catch {
            finish(.failure(UpdateError.downloadFailed))
        }
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let value = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        lock.lock()
        let progress = self.progress
        lock.unlock()
        Task { @MainActor in progress?(min(max(value, 0), 1)) }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let error else { return }
        if (error as NSError).code == NSURLErrorCancelled {
            finish(.failure(UpdateError.cancelled))
        } else {
            finish(.failure(UpdateError.downloadFailed))
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        let continuation = self.continuation
        let session = self.session
        self.continuation = nil
        self.session = nil
        self.task = nil
        self.progress = nil
        lock.unlock()

        session?.finishTasksAndInvalidate()
        continuation?.resume(with: result)
    }
}
