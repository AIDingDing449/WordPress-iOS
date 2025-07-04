import UIKit
import WordPressData
import WordPressFlux
import WordPressShared
import SwiftUI
import SVProgressHUD
import Gridicons
import PhotosUI

extension HomeSiteHeaderViewController {

    func makeSiteIconMenu() -> UIMenu? {
        UIMenu(options: .displayInline, children: [
            UIDeferredMenuElement.uncached { [weak self] in
                $0(self?.makeUpdateSiteIconActions() ?? [])
            }
        ])
    }

    private func makeUpdateSiteIconActions() -> [UIAction] {
        guard siteIconShouldAllowDroppedImages() else {
            return [] // Not eligible to change the icon
        }

        let presenter = makeSiteIconPresenter()
        let mediaMenu = MediaPickerMenu(viewController: self, filter: .images)
        var actions = [
            mediaMenu.makePhotosAction(delegate: presenter),
            mediaMenu.makeCameraAction(delegate: presenter),
            mediaMenu.makeImagePlaygroundAction(delegate: presenter),
            mediaMenu.makeSiteMediaAction(blog: blog, delegate: presenter)
        ].compactMap { $0 }
        if FeatureFlag.siteIconCreator.enabled {
            actions.append(UIAction(
                title: SiteIconAlertStrings.Actions.createWithEmoji,
                image: UIImage(systemName: "face.smiling"),
                handler: { [weak self] _ in self?.showEmojiPicker() }
            ))
        }
        if blog.hasIcon {
            actions.append(UIAction(
                title: SiteIconAlertStrings.Actions.removeSiteIcon,
                image: UIImage(systemName: "trash"),
                attributes: [.destructive],
                handler: { [weak self] _ in self?.removeSiteIcon() }
            ))
        }
        return actions
    }

    private func makeSiteIconPresenter() -> SiteIconPickerPresenter {
        let presenter = SiteIconPickerPresenter(blog: blog)
        presenter.onCompletion = { [ weak self] media, error in
            if error != nil {
                self?.showErrorForSiteIconUpdate()
            } else if let media {
                self?.updateBlogIconWithMedia(media)
            } else {
                // If no media and no error the picker was canceled
                self?.dismiss(animated: true)
            }

            self?.siteIconPickerPresenter = nil
        }
        presenter.onIconSelection = { [weak self] in
            self?.blogDetailHeaderView.updatingIcon = true
            self?.dismiss(animated: true)
        }
        self.siteIconPickerPresenter = presenter
        return presenter
    }

    func showEmojiPicker() {
        var pickerView = SiteIconPickerView()

        pickerView.onCompletion = { [weak self] image in
            self?.dismiss(animated: true, completion: nil)
            self?.blogDetailHeaderView.updatingIcon = true
            self?.uploadDroppedSiteIcon(image, completion: {})
        }

        pickerView.onDismiss = { [weak self] in
            self?.dismiss(animated: true)
        }

        let controller = UIHostingController(rootView: pickerView)
        present(controller, animated: true)
    }

    func removeSiteIcon() {
        blogDetailHeaderView.updatingIcon = true
        blog.settings?.iconMediaID = NSNumber(value: 0)
        updateBlogSettingsAndRefreshIcon()
        WPAnalytics.track(.siteSettingsSiteIconRemoved)
    }

    func showErrorForSiteIconUpdate() {
        SVProgressHUD.showDismissibleError(status: SiteIconAlertStrings.Errors.iconUpdateFailed)
        blogDetailHeaderView.updatingIcon = false
    }

    func updateBlogIconWithMedia(_ media: Media) {
        blog.settings?.iconMediaID = media.mediaID
        updateBlogSettingsAndRefreshIcon()
    }

    func updateBlogSettingsAndRefreshIcon() {
        blogService.updateSettings(for: blog, success: { [weak self] in
            guard let self else {
                return
            }
            self.blogService.syncBlog(self.blog, success: {
                self.blogDetailHeaderView.updatingIcon = false
                self.blogDetailHeaderView.refreshIconImage()
            }, failure: { _ in })

        }, failure: { [weak self] error in
            self?.showErrorForSiteIconUpdate()
        })
    }

    func uploadDroppedSiteIcon(_ image: UIImage, completion: @escaping (() -> Void)) {
        let service = MediaImportService(coreDataStack: ContextManager.shared)
        _ = service.createMedia(
            with: image,
            blog: blog,
            post: nil,
            receiveUpdate: nil,
            thumbnailCallback: nil,
            completion: {  [weak self] media, error in
                guard let media, error == nil else {
                    return
                }

                var uploadProgress: Progress?
                self?.mediaService.uploadMedia(
                    media,
                    automatedRetry: false,
                    progress: &uploadProgress,
                    success: {
                        self?.updateBlogIconWithMedia(media)
                        completion()
                    }, failure: { error in
                        self?.showErrorForSiteIconUpdate()
                        completion()
                    })
            })
    }

    func presentCropViewControllerForDroppedSiteIcon(_ image: UIImage?) {
        guard let image else {
            return
        }

        let imageCropController = ImageCropViewController(image: image)
        imageCropController.maskShape = .square
        imageCropController.shouldShowCancelButton = true

        imageCropController.onCancel = { [weak self] in
            self?.dismiss(animated: true)
            self?.blogDetailHeaderView.updatingIcon = false
        }

        imageCropController.onCompletion = { [weak self] image, modified in
            self?.dismiss(animated: true)
            self?.uploadDroppedSiteIcon(image, completion: {
                self?.blogDetailHeaderView.updatingIcon = false
            })
        }

        let navigationController = UINavigationController(rootViewController: imageCropController)
        navigationController.modalPresentationStyle = .formSheet
        present(navigationController, animated: true)
    }
}

extension HomeSiteHeaderViewController {

    private enum SiteIconAlertStrings {

        static let title = NSLocalizedString("Update Site Icon", comment: "Title for sheet displayed allowing user to update their site icon")

        enum Actions {
            static let createWithEmoji = NSLocalizedString("Create With Emoji", comment: "Button allowing the user to create a site icon by choosing an emoji character")
            static let removeSiteIcon = NSLocalizedString("Remove Site Icon", comment: "Remove site icon button")
            static let cancel = NSLocalizedString("Cancel", comment: "Cancel button")
        }

        enum Errors {
            static let iconUpdateFailed = NSLocalizedString("Icon update failed", comment: "Message to show when site icon update failed")
        }
    }
}
