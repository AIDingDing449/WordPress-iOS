import Foundation
import AsyncImageKit
import Support
import SwiftUI
import WordPressAPI
import WordPressAPIInternal // Needed for `SupportUserIdentity`
import WordPressCore
import WordPressData
import WordPressShared
import CocoaLumberjack

extension SupportDataProvider {
    @MainActor
    static let shared = SupportDataProvider(
        applicationLogProvider: WpLogDataProvider(),
        botConversationDataProvider: WpBotConversationDataProvider(
            wpcomClient: WordPressDotComClient()
        ),
        userDataProvider: WpCurrentUserDataProvider(
            wpcomClient: WordPressDotComClient()
        ),
        supportConversationDataProvider: WpSupportConversationDataProvider(
            wpcomClient: WordPressDotComClient()),
        delegate: WpSupportDelegate()
    )
}

actor WpLogDataProvider: ApplicationLogDataProvider {
    func fetchApplicationLogs() async throws -> [Support.ApplicationLog] {
        try WPLogger.shared().fileLogger
            .logFileManager
            .sortedLogFileInfos
            .compactMap { try ApplicationLog(filePath: $0.filePath) }
    }

    func deleteApplicationLogs(in logs: [Support.ApplicationLog]) async throws {
        for log in logs {
            try FileManager.default.removeItem(at: log.path)
        }
    }

    func deleteAllApplicationLogs() async throws {
        WPLogger.shared().deleteAllLogs()
    }
}

class WpSupportDelegate: NSObject, SupportDelegate {
    func userDid(_ action: Support.SupportFormAction) {

        switch action {
        case .viewApplicationLogList:
            WPAnalytics.track(.applicationLog, properties: [
                "subaction": "view-list"
            ])
        case .viewApplicationLog(let id):
            WPAnalytics.track(.applicationLog, properties: [
                "subaction": "view-single",
                "log_id": id
            ])
        case .deleteApplicationLogs(let ids):
            for id in ids {
                WPAnalytics.track(.applicationLog, properties: [
                    "subaction": "delete-log",
                    "log_id": id
                ])
            }
        case .deleteAllApplicationLogs:
            WPAnalytics.track(.applicationLog, properties: [
                "subaction": "delete-all"
            ])

        case .viewSupportBotConversationList:
            WPAnalytics.track(.supportChatbot, properties: [
                "subaction": "view-list"
            ])
        case .startSupportBotConversation:
            WPAnalytics.track(.supportChatbot, properties: [
                "subaction": "start-conversation"
            ])
        case .failToCreateBotConversation(let error):
            WPAnalytics.track(.supportChatbot, properties: [
                "subaction": "error-starting-conversation",
                "error": error.localizedDescription
            ])
        case .viewSupportBotConversation(let id):
            WPAnalytics.track(.supportChatbot, properties: [
                "subaction": "view-conversation",
                "conversation_id": id
            ])
        case .replyToSupportBotMessage(let id):
            WPAnalytics.track(.supportChatbot, properties: [
                "subaction": "reply-to-conversation",
                "conversation_id": id
            ])
        case .failToReplyToBotConversation(let error):
            WPAnalytics.track(.supportChatbot, properties: [
                "subaction": "error-replying-to-conversation",
                "error": error.localizedDescription
            ])
        case .viewSupportTicketList:
            WPAnalytics.track(.supportTickets, properties: [
                "subaction": "view-list"
            ])
        case .viewSupportTicket(let id):
            WPAnalytics.track(.supportTickets, properties: [
                "subaction": "view-ticket",
                "ticket_id": id
            ])
        case .createSupportTicket:
            WPAnalytics.track(.supportTickets, properties: [
                "subaction": "create-ticket",
            ])
        case .failToCreateSupportTicket(let error):
            WPAnalytics.track(.supportTickets, properties: [
                "subaction": "error-creating-ticket",
                "error": error.localizedDescription
            ])
        case .replyToSupportTicket(let id):
            WPAnalytics.track(.supportTickets, properties: [
                "subaction": "reply-to-ticket",
                "ticket_id": id
            ])
        case .failToReplyToSupportTicket(let error):
            WPAnalytics.track(.supportTickets, properties: [
                "subaction": "error-replying-to-ticket",
                "error": error.localizedDescription
            ])
        case .viewDiagnostics:
            WPAnalytics.track(.diagnostics, properties: [
                "subaction": "view-list"
            ])
        case .emptyDiskCache(bytesSaved: let bytesSaved):
            WPAnalytics.track(.diagnostics, properties: [
                "subaction": "empty-disk-cache",
                "bytes-saved": bytesSaved
            ])
        }
    }
}

actor WpBotConversationDataProvider: BotConversationDataProvider {

    private let botId = "jetpack-chat-mobile"

    private let wpcomClient: WordPressDotComClient

    private var conversationMessageStore: [UInt64: Support.BotConversation] = [:]

    init(wpcomClient: WordPressDotComClient) {
        self.wpcomClient = wpcomClient
    }

    nonisolated func loadBotConversations() throws -> any CachedAndFetchedResult<[Support.BotConversation]> {
        DiskCachedAndFetchedResult(fetchedResult: {
            try await self.wpcomClient
                .api
                .supportBots
                .getBotConverationList(botId: self.botId)
                .data
                .map { $0.asSupportConversation() }
        }, cacheKey: "bot-conversation-list")
    }

    nonisolated func loadBotConversation(id: UInt64) throws -> any CachedAndFetchedResult<Support.BotConversation> {
        return DiskCachedAndFetchedResult(fetchedResult: {
            let params = GetBotConversationParams(
                pageNumber: 1,
                itemsPerPage: 100,
                includeFeedback: false
            )

            let conversation = try await self.wpcomClient
                .api
                .supportBots
                .getBotConversation(botId: self.botId, chatId: ChatId(id), params: params)
                .data

            return conversation.asSupportConversation()
        }, cacheKey: "bot-conversation-\(id)")
    }

    func delete(conversationIds: [UInt64]) async throws {
        // TODO: Implement this
    }

    func sendMessage(message: String, in conversation: Support.BotConversation?) async throws -> Support.BotConversation {
        if let conversation {
            _ = try await add(message: message, to: conversation)
            return try await loadBotConversation(id: conversation.id).fetchedResult()
        } else {
            return try await createConversation(message: message)
        }
    }

    func createConversation(message: String) async throws -> Support.BotConversation {

        guard let accountId = try await ContextManager.shared
            .performQuery({ try WPAccount.lookupDefaultWordPressComAccount(in: $0)?.userID?.int64Value }) else {
                fatalError("Could not get the current user ID – this should never happen because users should be logged in")
            }

        let params: CreateBotConversationParams = CreateBotConversationParams(
            message: message,
            userId: accountId
        )

        let response = try await self.wpcomClient
            .api
            .supportBots
            .createBotConversation(botId: self.botId, params: params)
            .data

        return response.asSupportConversation()
    }

    private func add(message: String, to conversation: Support.BotConversation) async throws -> Support.BotConversation {
        let params: AddMessageToBotConversationParams = AddMessageToBotConversationParams(
            message: message,
            context: [:]
        )

        let response = try await self.wpcomClient
            .api
            .supportBots
            .addMessageToBotConversation(
                botId: self.botId,
                chatId: ChatId(conversation.id),
                params: params
            ).data

        return response.asSupportConversation()
    }
}

actor WpCurrentUserDataProvider: CurrentUserDataProvider {

    private let wpcomClient: WordPressDotComClient

    init(wpcomClient: WordPressDotComClient) {
        self.wpcomClient = wpcomClient
    }

    nonisolated func fetchCurrentSupportUser() throws -> any CachedAndFetchedResult<Support.SupportUser> {
        DiskCachedAndFetchedResult(fetchedResult: {
            async let user = try await self.wpcomClient.api.me.get().data.asSupportIdentity()
            async let eligibility = try await self.wpcomClient.api.supportEligibility.getSupportEligibility().data

            let supportUser = try await user.applyingSupportEligibility(eligibility)
            return supportUser
        }, cacheKey: "current-support-user")
    }
}

actor WpSupportConversationDataProvider: SupportConversationDataProvider {

    private let wpcomClient: WordPressDotComClient

    init(wpcomClient: WordPressDotComClient) {
        self.wpcomClient = wpcomClient
    }

    nonisolated func loadSupportConversations() throws -> any CachedAndFetchedResult<[ConversationSummary]> {
        return DiskCachedAndFetchedResult(fetchedResult: {
            try await self.wpcomClient.api
                .supportTickets
                .getSupportConversationList()
                .data
                .map { $0.asConversationSummary() }
        }, cacheKey: "support-conversation-list")
    }

    nonisolated func loadSupportConversation(id: UInt64) throws -> any CachedAndFetchedResult<Conversation> {
        return DiskCachedAndFetchedResult(fetchedResult: {
            try await self.wpcomClient.api
                .supportTickets
                .getSupportConversation(conversationId: id)
                .data
                .asConversation()
        }, cacheKey: "support-conversation-\(id)")
    }

    func createSupportConversation(
        subject: String,
        message: String,
        user: SupportUser,
        attachments: [URL]
    ) async throws -> Conversation {
        let params = CreateSupportTicketParams(
            subject: subject,
            message: message,
            application: "jetpack"
        )

        return try await self.wpcomClient.api
            .supportTickets
            .createSupportTicket(params: params)
            .data
            .asConversation()
    }

    func replyToSupportConversation(
        id: UInt64,
        message: String,
        user: SupportUser,
        attachments: [URL]
    ) async throws -> Conversation {
        let params = AddMessageToSupportConversationParams(
            message: message,
            attachments: attachments.map { $0.path() }
        )

        let conversation = try await self.wpcomClient.api
            .supportTickets
            .addMessageToSupportConversation(conversationId: id, params: params)
            .data
            .asConversation()

        return conversation
    }
}

extension WPComApiClient: @retroactive @unchecked Sendable {}

extension WpComUserInfo {
    func asSupportIdentity() async throws -> SupportUser {
        SupportUser(
            userId: self.id,
            username: self.displayName,
            email: self.email,
            avatarUrl: self.getAvatarUrl()
        )
    }

    func getAvatarUrl() -> URL? {
        guard let urlString = self.avatarUrl, let url = URL(string: urlString) else {
            return nil
        }

        return url
    }
}

extension SupportUser {
    func applyingSupportEligibility(_ eligiblity: SupportEligibility) -> SupportUser {
        var permissions = [SupportUserPermission]()

        if eligiblity.isUserEligible {
            permissions = [.createSupportRequest, .createChatConversation]
        }

        return SupportUser(
            userId: self.userId,
            username: self.username,
            email: self.email,
            permissions: permissions,
            avatarUrl: self.avatarUrl,
        )
    }
}

extension WordPressAPIInternal.BotConversationSummary {
    func asSupportConversation() -> Support.BotConversation {
        var summary = self.lastMessage.content

        if let preview = summary.components(separatedBy: .newlines).first?.prefix(64) {
            summary = String(preview)
        }

        return BotConversation(
            id: self.chatId,
            title: summary,
            mostRecentMessageDate: self.lastMessage.createdAt,
            messages: []
        )
    }
}

extension WordPressAPIInternal.BotConversation {
    func asSupportConversation() -> Support.BotConversation {
        BotConversation(
            id: self.chatId,
            title: self.messages.first?.content ?? "New Bot Chat",
            mostRecentMessageDate: self.messages.last?.createdAt ?? self.createdAt,
            messages: self.messages.map { $0.asSupportMessage() }
        )
    }
}

extension WordPressAPIInternal.BotMessage {
    func asSupportMessage() -> Support.BotMessage {
        return switch context {

        case .bot(let botContext): Support.BotMessage(
            id: self.messageId,
            text: self.content,
            date: self.createdAt,
            userWantsToTalkToHuman: botContext.userWantsToTalkToAHuman,
            isWrittenByUser: false
        )
        case .user: Support.BotMessage(
            id: self.messageId,
            text: self.content,
            date: self.createdAt,
            userWantsToTalkToHuman: false,
            isWrittenByUser: true
        )
        }
    }
}

extension WordPressAPIInternal.SupportConversationSummary {
    func asConversationSummary() -> Support.ConversationSummary {
        Support.ConversationSummary(
            id: self.id,
            title: self.title,
            description: self.description,
            lastMessageSentAt: self.updatedAt
        )
    }
}

extension SupportConversation {
    func asConversation() -> Conversation {
        Conversation(
            id: self.id,
            title: self.title,
            description: self.description,
            lastMessageSentAt: self.updatedAt,
            messages: self.messages.map { $0.asMessage() }
        )
    }
}

extension SupportMessage {
    func asMessage() -> Message {
        return switch self.author {
        case .user(let user): Message(
            id: self.id,
            content: self.content,
            createdAt: self.createdAt,
            authorName: user.displayName,
            authorIsUser: true,
            attachments: self.attachments.map { $0.asAttachment() }
        )
        case .supportAgent(let agent): Message(
            id: self.id,
            content: self.content,
            createdAt: self.createdAt,
            authorName: agent.name,
            authorIsUser: false,
            attachments: self.attachments.map { $0.asAttachment() }
        )
        }
    }
}

extension SupportAttachment {
    func asAttachment() -> Attachment {
        Attachment(
            id: self.id
        )
    }
}
