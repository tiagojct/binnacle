import Foundation

final class FileWatcher: NSObject, NSFilePresenter {
    let fileURL: URL
    var onFileChanged: (() -> Void)?

    var presentedItemURL: URL? { fileURL }
    var presentedItemOperationQueue: OperationQueue { .main }

    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }

    func presentedItemDidChange() {
        onFileChanged?()
    }

    func stop() {
        NSFileCoordinator.removeFilePresenter(self)
    }

    deinit {
        stop()
    }
}
