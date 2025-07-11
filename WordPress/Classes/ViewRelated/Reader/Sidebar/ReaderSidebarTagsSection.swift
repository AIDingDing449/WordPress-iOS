import UIKit
import SwiftUI
import Combine
import WordPressData
import WordPressUI

struct ReaderSidebarTagsSection: View {
    let viewModel: ReaderSidebarViewModel

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.title, order: .forward)],
        predicate: ReaderSidebarTagsSection.predicate
    )
    private var tags: FetchedResults<ReaderTagTopic>

    static let predicate = NSPredicate(format: "following == YES AND showInMenu == YES AND type == 'tag'")

    var body: some View {
        ForEach(tags, id: \.self) { tag in
            Label {
                Text(tag.title)
                    .lineLimit(1)
            } icon: {
                ReaderSidebarImage(name: "reader-menu-tag")
                    .foregroundStyle(.secondary)
            }
            .tag(ReaderSidebarItem.tag(TaggedManagedObjectID(tag)))
            .swipeActions(edge: .trailing) {
                Button(SharedStrings.Reader.unfollow, role: .destructive) {
                    ReaderTagsHelper().unfollow(tag)
                }.tint(.red)
            }
            .contextMenu(menuItems: {
                Button(SharedStrings.Reader.unfollow, systemImage: "trash", role: .destructive) {
                    ReaderTagsHelper().unfollow(tag)
                }
            }, preview: {
                ReaderTopicPreviewView(topic: tag)
            })
        }
        .onDelete(perform: delete)
    }

    func delete(at offsets: IndexSet) {
        let tags = offsets.map { self.tags[$0] }
        for tag in tags {
            ReaderTagsHelper().unfollow(tag)
        }
    }
}

private struct Strings {
    static let addTag = NSLocalizedString("reader.sidebar.section.tags.addTag", value: "Add tag", comment: "Reader sidebar button")
    static let discoverTags = NSLocalizedString("reader.sidebar.section.tags.discoverTags", value: "Discover More Tags", comment: "Reader sidebar button")
}
