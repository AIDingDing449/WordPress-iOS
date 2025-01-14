import UIKit

/// A convenience class for managing image downloads for individual views.
@MainActor
public final class ImageLoadingController {
    public var downloader: ImageDownloader = .shared
    public var onStateChanged: (State) -> Void = { _ in }

    public private(set) var task: Task<Void, Never>?

    public enum State {
        case loading
        case success(UIImage)
        case failure(Error)
    }

    deinit {
        task?.cancel()
    }

    public init() {}

    public func prepareForReuse() {
        task?.cancel()
        task = nil
    }

    /// - parameter completion: Gets called on completion _after_ `onStateChanged`.
    public func setImage(with request: ImageRequest, completion: (@MainActor (Result<UIImage, Error>) -> Void)? = nil) {
        task?.cancel()

        if let image = downloader.cachedImage(for: request) {
            onStateChanged(.success(image))
            completion?(.success(image))
        } else {
            onStateChanged(.loading)
            task = Task { @MainActor [downloader, weak self] in
                do {
                    let image = try await downloader.image(for: request)
                    // This line guarantees that if you cancel on the main thread,
                    // none of the `onStateChanged` callbacks get called.
                    guard !Task.isCancelled else { return }
                    self?.onStateChanged(.success(image))
                    completion?(.success(image))
                } catch {
                    guard !Task.isCancelled else { return }
                    self?.onStateChanged(.failure(error))
                    completion?(.failure(error))
                }
            }
        }
    }
}
