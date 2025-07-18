import UIKit
import SwiftUI
import WordPressData
import WordPressUI
import WordPressShared
import Photos
import PhotosUI

/// A media picker menu
struct MediaPicker<Content: View>: View {
    var configuration = MediaPickerConfiguration()
    var onSelection: ((MediaPickerSelection) -> Void)?

    @ViewBuilder var content: () -> Content

    @StateObject private var viewModel = MediaPickerViewModel()

    var body: some View {
        Menu {
            menu
        } label: {
            content()
        }
    }

    @ViewBuilder
    private var menu: some View {
        ForEach(makeActions(), id: \.self) { action in
            Button {
                action.performWithSender(nil, target: nil)
            } label: {
                Label {
                    Text(action.title)
                } icon: {
                    action.image.map(Image.init)
                }
            }
        }
    }

    private func makeActions() -> [UIAction] {
        let menu = MediaPickerMenu(
            filter: configuration.filter,
            isMultipleSelectionEnabled: configuration.isMultipleSelectionEnabled
        )

        let controller = MediaPickerMenuController()
        controller.onSelection = onSelection
        viewModel.controller = controller // Needs to be retained

        return configuration.sources.filter(\.isEnabled).compactMap { source in
            switch source {
            case .photos:
                menu.makePhotosAction(delegate: controller)
            case .camera:
                 menu.makeCameraAction(delegate: controller)
            case .siteMedia(let blog):
                menu.makeSiteMediaAction(blog: blog, delegate: controller)
            case .playground:
                menu.makeImagePlaygroundAction(delegate: controller)
            case .freePhotos(let blog):
                menu.makeStockPhotos(blog: blog, delegate: controller)
            case .freeGIFs(let blog):
                menu.makeFreeGIFAction(blog: blog, delegate: controller)
            }
        }
    }
}

struct MediaPickerConfiguration {
    var sources: [MediaPickerSource] = [.photos, .camera]
    var filter: MediaPickerMenu.MediaFilter?
    var isMultipleSelectionEnabled = false
}

private final class MediaPickerViewModel: ObservableObject {
    var controller: MediaPickerMenuController?
}

enum MediaPickerSource {
    case photos // Apple Photos
    case camera
    case siteMedia(blog: Blog)
    case playground // Image Playground
    case freePhotos(blog: Blog) // Pexels
    case freeGIFs(blog: Blog) // Tenor

    var isEnabled: Bool {
        switch self {
        case .photos, .camera, .siteMedia:
            true
        case .playground:
            MediaPickerMenu.isImagePlaygroundAvailable
        case .freePhotos(let blog):
            blog.supports(.stockPhotos) && JetpackFeaturesRemovalCoordinator.jetpackFeaturesEnabled()
        case .freeGIFs:
            JetpackFeaturesRemovalCoordinator.jetpackFeaturesEnabled()
        }
    }
}

struct MediaPickerSelection {
    var items: [MediaPickerItem]
    var source: String
}

enum MediaPickerItem {
    case pickerResult(PHPickerResult)
    case image(UIImage)
    case media(Media)
    case external(ExternalMediaAsset)

    /// Prepares the item for export and upload to your site media. If the item
    /// is already uploaded, returns `Media`.
    func exported() -> Exportable {
        switch self {
        case .pickerResult(let result):
            return .asset(result.itemProvider)
        case .image(let image):
            return .asset(image)
        case .media(let media):
            return .media(media)
        case .external(let asset):
            return .asset(asset)
        }
    }

    enum Exportable {
        case asset(ExportableAsset)
        case media(Media)
    }
}
