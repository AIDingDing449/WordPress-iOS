import Foundation
import WordPressData
import WordPressKit
import WordPressFlux
import WordPressShared

enum StatsSummaryTimeIntervalDataAsAWeek {
    case thisWeek(data: StatsSummaryTimeIntervalData)
    case prevWeek(data: StatsSummaryTimeIntervalData)
}

struct StatsInsightsSection: Hashable {
    let insightType: InsightType?

    init(insightType: InsightType?) {
        self.insightType = insightType
    }
}

/// The view model used by Stats Insights.
///
class SiteStatsInsightsViewModel: Observable {

    // MARK: - Properties

    let changeDispatcher = Dispatcher<Void>()

    private weak var siteStatsInsightsDelegate: SiteStatsInsightsDelegate?
    private weak var viewsAndVisitorsDelegate: StatsInsightsViewsAndVisitorsDelegate?

    private let insightsStore: StatsInsightsStore
    private let periodStore: StatsPeriodStore
    private var insightsReceipt: Receipt?
    private var insightsChangeReceipt: Receipt?
    private var insightsToShow = [InsightType]()
    private(set) var lastRequestedDate: Date
    private(set) var lastRequestedPeriod: StatsPeriodUnit

    private let pinnedItemStore: SiteStatsPinnedItemStore?
    private let itemToDisplay: SiteStatsPinnable?
    private var isNudgeCompleted: Bool {
        guard let pinnedItemStore, let item = itemToDisplay, item is GrowAudienceCell.HintType else {
            return false
        }
        return !pinnedItemStore.shouldShow(item)
    }

    private var periodChangeReceipt: Receipt?

    private typealias Style = WPStyleGuide.Stats

    private var mostRecentChartData: StatsSummaryTimeIntervalData? {
        periodStore.getSummary()
    }

    private var selectedViewsVisitorsSegment: StatsSegmentedControlData.Segment = .views

    // MARK: - Constructor

    init(insightsToShow: [InsightType],
         insightsDelegate: SiteStatsInsightsDelegate,
         viewsAndVisitorsDelegate: StatsInsightsViewsAndVisitorsDelegate?,
         insightsStore: StatsInsightsStore,
         pinnedItemStore: SiteStatsPinnedItemStore?,
         periodStore: StatsPeriodStore = StatsPeriodStore()) {
        self.siteStatsInsightsDelegate = insightsDelegate
        self.viewsAndVisitorsDelegate = viewsAndVisitorsDelegate
        self.insightsToShow = insightsToShow
        self.insightsStore = insightsStore
        self.pinnedItemStore = pinnedItemStore
        self.periodStore = periodStore
        let viewsCount = insightsStore.getAllTimeStats()?.viewsCount ?? 0
        self.itemToDisplay = pinnedItemStore?.itemToDisplay(for: viewsCount)

        // Exclude today's data for weekly insights
        self.lastRequestedDate = StatsDataHelper.yesterdayDateForSite()
        self.lastRequestedPeriod = StatsPeriodUnit.day
    }

    /// This method will trigger a refresh of insights data, provided that we're not already
    /// performing a refresh and that we haven't refreshed within the last 5 minutes.
    /// To override this caching and request the latest data (for example, when as the result
    /// of a pull to refresh action), you can pass a `forceRefresh` value of `true` here.
    ///
    func refreshInsights(forceRefresh: Bool = false) {
        loadCachedInsights()

        /// Refresh Insights data if needed
        ActionDispatcher.dispatch(InsightAction.refreshInsights(forceRefresh: forceRefresh))

        startFetchingPeriodOverview()
    }

    private func loadCachedInsights() {
        insightsReceipt = nil
        insightsReceipt = insightsStore.query(.insights)
    }

    private func startFetchingPeriodOverview() {
        periodStore.actionDispatcher.dispatch(PeriodAction.refreshPeriodOverviewData(date: lastRequestedDate,
                period: lastRequestedPeriod,
                forceRefresh: true))
    }

    // MARK: - Listeners

    func addListeners() {
        insightsChangeReceipt = self.insightsStore.onChange { [weak self] in
            self?.emitChange()
        }

        periodChangeReceipt = self.periodStore.onChange { [weak self] in
            self?.emitChange()
        }
    }

    func removeListeners() {
        periodChangeReceipt = nil
        insightsChangeReceipt = nil
        insightsReceipt = nil
    }

    // MARK: - Table Model

    func tableViewSnapshot() -> ImmuTableDiffableDataSourceSnapshot {
        var snapshot = ImmuTableDiffableDataSourceSnapshot()

        if insightsToShow.isEmpty ||
            (fetchingFailed() && !containsCachedData()) {
            return snapshot
        }

        for insightType in insightsToShow {
            let errorBlock = { statSection in
                return StatsErrorRow(rowStatus: .error, statType: .insights, statSection: statSection)
            }

            switch insightType {
            case .viewsVisitors:
                let viewsVisitorsSection = StatsInsightsSection(insightType: .viewsVisitors)
                let viewsVisitorsRows = blocks(for: .viewsVisitors,
                                               type: .period,
                                               status: periodStore.timeIntervalsSummaryStatus,
                                               checkingCache: { [weak self] in
                    return self?.mostRecentChartData != nil
                },
                                               block: { [weak self] in
                    return self?.overviewTableRows() ?? [errorBlock(.insightsViewsVisitors)]
                }, loading: {
                    return [StatsGhostChartImmutableRow(statSection: .insightsViewsVisitors)]
                }, error: {
                    return [errorBlock(.insightsViewsVisitors)]
                })
                    .map { AnyHashableImmuTableRow(immuTableRow: $0) }
                snapshot.appendSections([viewsVisitorsSection])
                snapshot.appendItems(viewsVisitorsRows, toSection: viewsVisitorsSection)
            case .growAudience:
                /// Grow Audience is an additional informational card that is not added by the user, no need to show it if fails to load
                guard insightsStore.allTimeStatus != . error else {
                    break
                }

                let growAudienceSection = StatsInsightsSection(insightType: .growAudience)
                let growAudienceRows: [any StatsHashableImmuTableRow] = blocks(for: .growAudience,
                                                                          type: .insights,
                                                                          status: insightsStore.allTimeStatus,
                                                                          block: {
                    let nudge = itemToDisplay as? GrowAudienceCell.HintType ?? GrowAudienceCell.HintType.social
                    let viewsCount = insightsStore.getAllTimeStats()?.viewsCount ?? 0
                    return [GrowAudienceRow(hintType: nudge,
                                            allTimeViewsCount: viewsCount,
                                            isNudgeCompleted: isNudgeCompleted,
                                            siteStatsInsightsDelegate: siteStatsInsightsDelegate,
                                            statSection: nil)]
                }, loading: {
                    return [StatsGhostGrowAudienceImmutableRow(statSection: InsightType.growAudience.statSection)]
                }, error: {
                    [errorBlock(nil)]
                })
                snapshot.appendSections([growAudienceSection])
                snapshot.appendItems(growAudienceRows.map { AnyHashableImmuTableRow(immuTableRow: $0) }, toSection: growAudienceSection)
            case .latestPostSummary:
                let latestPostSummarySection = StatsInsightsSection(insightType: .latestPostSummary)
                let latestPostSummaryRows: [any StatsHashableImmuTableRow] = blocks(for: .latestPostSummary,
                                                                               type: .insights,
                                                                               status: insightsStore.lastPostSummaryStatus,
                                                                               block: {
                    return [LatestPostSummaryRow(summaryData: insightsStore.getLastPostInsight(),
                                                chartData: insightsStore.getPostStats(),
                                                siteStatsInsightsDelegate: siteStatsInsightsDelegate,
                                                statSection: .insightsLatestPostSummary)]
                }, loading: {
                    return [StatsGhostChartImmutableRow(statSection: .insightsLatestPostSummary)]
                }, error: {
                    [errorBlock(.insightsLatestPostSummary)]
                })
                snapshot.appendSections([latestPostSummarySection])
                snapshot.appendItems(latestPostSummaryRows.map { AnyHashableImmuTableRow(immuTableRow: $0) }, toSection: latestPostSummarySection)
            case .allTimeStats:
                let allTimeStatsSection = StatsInsightsSection(insightType: .allTimeStats)
                let allTimeStatsRows: [any StatsHashableImmuTableRow] = blocks(for: .allTimeStats,
                                              type: .insights,
                                              status: insightsStore.allTimeStatus,
                                              block: {
                    return [TwoColumnStatsRow(dataRows: createAllTimeStatsRows(),
                                             statSection: .insightsAllTime,
                                             siteStatsInsightsDelegate: nil)]
                }, loading: {
                    return [StatsGhostTwoColumnImmutableRow(statSection: .insightsAllTime)]
                }, error: {
                    [errorBlock(.insightsAllTime)]
                })

                snapshot.appendSections([allTimeStatsSection])
                snapshot.appendItems(allTimeStatsRows.map { AnyHashableImmuTableRow(immuTableRow: $0) }, toSection: allTimeStatsSection)
            case .likesTotals:
                let likesTotalsSection = StatsInsightsSection(insightType: .likesTotals)
                let likesTotalsRows: [any StatsHashableImmuTableRow] = blocks(for: .likesTotals,
                                             type: .period,
                                             status: periodStore.timeIntervalsSummaryStatus,
                                             checkingCache: { [weak self] in
                    return self?.mostRecentChartData != nil
                },
                                             block: {
                    return [TotalInsightStatsRow(dataRow: createLikesTotalInsightsRow(), statSection: .insightsLikesTotals, siteStatsInsightsDelegate: siteStatsInsightsDelegate)]
                }, loading: {
                    return [StatsGhostTwoColumnImmutableRow(statSection: .insightsLikesTotals)]
                }, error: {
                    [errorBlock(.insightsLikesTotals)]
                })

                snapshot.appendSections([likesTotalsSection])
                snapshot.appendItems(likesTotalsRows.map { AnyHashableImmuTableRow(immuTableRow: $0) }, toSection: likesTotalsSection)
            case .commentsTotals:
                let commentsTotalsSection = StatsInsightsSection(insightType: .commentsTotals)
                let commentsTotalsRows: [any StatsHashableImmuTableRow] = blocks(for: .commentsTotals,
                                                type: .period,
                                                status: periodStore.timeIntervalsSummaryStatus,
                                                checkingCache: { [weak self] in
                    return self?.mostRecentChartData != nil
                },
                                                block: {
                    return [TotalInsightStatsRow(dataRow: createCommentsTotalInsightsRow(), statSection: .insightsCommentsTotals, siteStatsInsightsDelegate: siteStatsInsightsDelegate)]
                }, loading: {
                    return [StatsGhostTwoColumnImmutableRow(statSection: .insightsCommentsTotals)]
                }, error: {
                    [errorBlock(.insightsCommentsTotals)]
                })

                snapshot.appendSections([commentsTotalsSection])
                snapshot.appendItems(commentsTotalsRows.map { AnyHashableImmuTableRow(immuTableRow: $0) }, toSection: commentsTotalsSection)
            case .followersTotals:
                let followersTotalsSection = StatsInsightsSection(insightType: .followersTotals)
                let followersTotalsRows: [any StatsHashableImmuTableRow] = blocks(for: .followersTotals,
                                                 type: .insights,
                                                 status: insightsStore.followersTotalsStatus,
                                                 block: {
                    return [TotalInsightStatsRow(dataRow: createFollowerTotalInsightsRow(), statSection: .insightsFollowerTotals, siteStatsInsightsDelegate: siteStatsInsightsDelegate)]
                }, loading: {
                    return [StatsGhostTwoColumnImmutableRow(statSection: .insightsFollowerTotals)]
                }, error: {
                    [errorBlock(.insightsFollowerTotals)]
                })

                snapshot.appendSections([followersTotalsSection])
                snapshot.appendItems(followersTotalsRows.map { AnyHashableImmuTableRow(immuTableRow: $0) }, toSection: followersTotalsSection)
            case .mostPopularTime:
                let mostPopularTimeSection = StatsInsightsSection(insightType: .mostPopularTime)
                let mostPopularTimeRows: [any StatsHashableImmuTableRow] = blocks(for: .mostPopularTime,
                                                 type: .insights,
                                                 status: insightsStore.annualAndMostPopularTimeStatus,
                                                 block: {
                    return [MostPopularTimeInsightStatsRow(data: createMostPopularStatsRowData(),
                                                          siteStatsInsightsDelegate: nil,
                                                          statSection: .insightsMostPopularTime)]
                }, loading: {
                    return [StatsGhostTwoColumnImmutableRow(statSection: .insightsMostPopularTime)]
                }, error: {
                    [errorBlock(.insightsMostPopularTime)]
                })

                snapshot.appendSections([mostPopularTimeSection])
                snapshot.appendItems(mostPopularTimeRows.map { AnyHashableImmuTableRow(immuTableRow: $0) }, toSection: mostPopularTimeSection)
            case .tagsAndCategories:
                let tagsAndCategoriesSection = StatsInsightsSection(insightType: .tagsAndCategories)
                let tagsAndCategoriesRows: [any StatsHashableImmuTableRow] = blocks(for: .tagsAndCategories,
                                                   type: .insights,
                                                   status: insightsStore.tagsAndCategoriesStatus,
                                                   block: {
                    return [TopTotalsInsightStatsRow(itemSubtitle: StatSection.insightsTagsAndCategories.itemSubtitle,
                                                    dataSubtitle: StatSection.insightsTagsAndCategories.dataSubtitle,
                                                    dataRows: createTagsAndCategoriesRows(),
                                                    statSection: .insightsTagsAndCategories,
                                                    siteStatsInsightsDelegate: siteStatsInsightsDelegate)]
                }, loading: {
                    return [StatsGhostTopImmutableRow(statSection: .insightsTagsAndCategories)]
                }, error: {
                    [errorBlock(.insightsTagsAndCategories)]
                })

                snapshot.appendSections([tagsAndCategoriesSection])
                snapshot.appendItems(tagsAndCategoriesRows.map { AnyHashableImmuTableRow(immuTableRow: $0) }, toSection: tagsAndCategoriesSection)
            case .annualSiteStats:
                let annualSiteStatsSection = StatsInsightsSection(insightType: .annualSiteStats)
                let annualSiteStatsRows: [any StatsHashableImmuTableRow] = blocks(for: .annualSiteStats,
                                                 type: .insights,
                                                 status: insightsStore.annualAndMostPopularTimeStatus,
                                                 block: {
                    return [TwoColumnStatsRow(dataRows: createAnnualRows(),
                                             statSection: .insightsAnnualSiteStats,
                                             siteStatsInsightsDelegate: siteStatsInsightsDelegate)]
                }, loading: {
                    return [StatsGhostTwoColumnImmutableRow(statSection: .insightsAnnualSiteStats)]
                }, error: {
                    [errorBlock(.insightsAnnualSiteStats)]
                })

                snapshot.appendSections([annualSiteStatsSection])
                snapshot.appendItems(annualSiteStatsRows.map { AnyHashableImmuTableRow(immuTableRow: $0) }, toSection: annualSiteStatsSection)
            case .comments:
                let commentsSection = StatsInsightsSection(insightType: .comments)
                let commentsRows: [any StatsHashableImmuTableRow] = blocks(for: .comments,
                                          type: .insights,
                                          status: insightsStore.commentsInsightStatus,
                                          block: {
                    return [createCommentsRow()]
                }, loading: {
                    return [StatsGhostTabbedImmutableRow(statSection: .insightsCommentsAuthors)]
                }, error: {
                    [errorBlock(.insightsCommentsPosts)]
                })

                snapshot.appendSections([commentsSection])
                snapshot.appendItems(commentsRows.map { AnyHashableImmuTableRow(immuTableRow: $0) }, toSection: commentsSection)
            case .followers:
                let followersSection = StatsInsightsSection(insightType: .followers)
                let followersRows: [any StatsHashableImmuTableRow] = blocks(for: .followers,
                                           type: .insights,
                                           status: insightsStore.followersTotalsStatus,
                                           block: {
                    return [createFollowersRow()]
                }, loading: {
                    return [StatsGhostTabbedImmutableRow(statSection: .insightsFollowersWordPress)]
                }, error: {
                    [errorBlock(.insightsFollowersWordPress)]
                })

                snapshot.appendSections([followersSection])
                snapshot.appendItems(followersRows.map { AnyHashableImmuTableRow(immuTableRow: $0) }, toSection: followersSection)
            case .todaysStats:
                let todaysStatsSection = StatsInsightsSection(insightType: .todaysStats)
                let todaysStatsRows: [any StatsHashableImmuTableRow] = blocks(for: .todaysStats,
                                             type: .insights,
                                             status: insightsStore.todaysStatsStatus,
                                             block: {
                    return [TwoColumnStatsRow(dataRows: createTodaysStatsRows(),
                                             statSection: .insightsTodaysStats,
                                             siteStatsInsightsDelegate: nil)]
                }, loading: {
                    return [StatsGhostTwoColumnImmutableRow(statSection: .insightsTodaysStats)]
                }, error: {
                    [errorBlock(.insightsTodaysStats)]
                })

                snapshot.appendSections([todaysStatsSection])
                snapshot.appendItems(todaysStatsRows.map { AnyHashableImmuTableRow(immuTableRow: $0) }, toSection: todaysStatsSection)
            case .postingActivity:
                let postingActivitySection = StatsInsightsSection(insightType: .postingActivity)
                let postingActivityRows: [any StatsHashableImmuTableRow] = blocks(for: .postingActivity,
                                                 type: .insights,
                                                 status: insightsStore.postingActivityStatus,
                                                 block: {
                    return [createPostingActivityRow()]
                }, loading: {
                    return [StatsGhostPostingActivitiesImmutableRow(statSection: .insightsPostingActivity)]
                }, error: {
                    [errorBlock(.insightsPostingActivity)]
                })

                snapshot.appendSections([postingActivitySection])
                snapshot.appendItems(postingActivityRows.map { AnyHashableImmuTableRow(immuTableRow: $0) }, toSection: postingActivitySection)
            case .publicize:
                let publicizeSection = StatsInsightsSection(insightType: .publicize)
                let publicizeRows: [any StatsHashableImmuTableRow] = blocks(for: .publicize,
                                           type: .insights,
                                           status: insightsStore.publicizeFollowersStatus,
                                           block: {
                    return [TopTotalsInsightStatsRow(itemSubtitle: StatSection.insightsPublicize.itemSubtitle,
                                                    dataSubtitle: StatSection.insightsPublicize.dataSubtitle,
                                                    dataRows: createPublicizeRows(),
                                                    statSection: .insightsPublicize,
                                                    siteStatsInsightsDelegate: nil)]
                }, loading: {
                    return [StatsGhostTopImmutableRow(statSection: .insightsPublicize)]
                }, error: {
                    [errorBlock(.insightsPublicize)]
                })
                snapshot.appendSections([publicizeSection])
                snapshot.appendItems(publicizeRows.map { AnyHashableImmuTableRow(immuTableRow: $0) }, toSection: publicizeSection)
            default:
                break
            }
        }

        let addInsightSection = StatsInsightsSection(insightType: nil)
        let addInsightRow = AddInsightRow(action: { [weak self] _ in
            self?.siteStatsInsightsDelegate?.showAddInsight?()
        }, statSection: .insightsAddInsight)
        snapshot.appendSections([addInsightSection])
        snapshot.appendItems([AnyHashableImmuTableRow(immuTableRow: addInsightRow)], toSection: addInsightSection)

        return snapshot
    }

    func fetchingFailed() -> Bool {
        return insightsStore.fetchingFailed(for: .insights)
    }

    func containsCachedData() -> Bool {
        return insightsStore.containsCachedData(for: insightsToShow)
    }

    func annualInsightsYear() -> String? {
        return insightsStore.getAnnualAndMostPopularTime()?.years?.last?.year
    }

    func updateInsightsToShow(insights: [InsightType]) {
        insightsToShow = insights
    }

    func markEmptyStatsNudgeAsCompleted() {
        guard let item = itemToDisplay else {
            return
        }
        pinnedItemStore?.markPinnedItemAsHidden(item)
    }

    func updateViewsAndVisitorsSegment(_ selectedSegment: StatsSegmentedControlData.Segment) {
        selectedViewsVisitorsSegment = selectedSegment
    }

    static func intervalData(_ statsSummaryTimeIntervalData: StatsSummaryTimeIntervalData?, summaryType: StatsSummaryType, periodEndDate: Date? = nil) -> (count: Int, prevCount: Int, difference: Int, percentage: Int) {
        guard let statsSummaryTimeIntervalData else {
            return (0, 0, 0, 0)
        }

        let splitSummaryTimeIntervalData = SiteStatsInsightsViewModel.splitStatsSummaryTimeIntervalData(statsSummaryTimeIntervalData, periodEndDate: periodEndDate)

        var currentCount: Int = 0
        var previousCount: Int = 0

        splitSummaryTimeIntervalData.forEach { week in
            switch week {
            case .thisWeek(let data):
                switch summaryType {
                case .views:
                    currentCount = data.summaryData.compactMap({$0.viewsCount}).reduce(0, +)
                case .visitors:
                    currentCount = data.summaryData.compactMap({$0.visitorsCount}).reduce(0, +)
                case .likes:
                    currentCount = data.summaryData.compactMap({$0.likesCount}).reduce(0, +)
                case .comments:
                    currentCount = data.summaryData.compactMap({$0.commentsCount}).reduce(0, +)
                }
            case .prevWeek(let data):
                switch summaryType {
                case .views:
                    previousCount = data.summaryData.compactMap({$0.viewsCount}).reduce(0, +)
                case .visitors:
                    previousCount = data.summaryData.compactMap({$0.visitorsCount}).reduce(0, +)
                case .likes:
                    previousCount = data.summaryData.compactMap({$0.likesCount}).reduce(0, +)
                case .comments:
                    previousCount = data.summaryData.compactMap({$0.commentsCount}).reduce(0, +)
                }
            }
        }

        let difference = currentCount - previousCount
        var roundedPercentage = 0

        if previousCount > 0 {
            let percentage = (Float(difference) / Float(previousCount)) * 100
            roundedPercentage = Int(round(percentage))
        }

        return (currentCount, previousCount, difference, roundedPercentage)
    }

    var followTopicsViewController: ReaderSelectInterestsViewController {
        let configuration = ReaderSelectInterestsConfiguration(title: NSLocalizedString("Follow topics", comment: "Screen title. Reader select interests title label text."),
                                                               subtitle: nil,
                                                               buttonTitle: nil,
                                                               loading: NSLocalizedString("Following new topics...", comment: "Label displayed to the user while loading their selected interests")
        )

        let context = ContextManager.shared.mainContext
        let topics: [ReaderTagTopic]
        if let fetchRequest = ReaderTagTopic.tagsFetchRequest as? NSFetchRequest<ReaderTagTopic>,
           let fetchedTopics = try? context.fetch(fetchRequest) {
            topics = fetchedTopics
        } else {
            topics = []
        }

        return ReaderSelectInterestsViewController(configuration: configuration, topics: topics)
    }
}

// MARK: - Private Extension

private extension SiteStatsInsightsViewModel {

    struct AllTimeStats {
        static let postsTitle = NSLocalizedString("Posts", comment: "All Time Stats 'Posts' label")
        static let viewsTitle = NSLocalizedString("Views", comment: "All Time Stats 'Views' label")
        static let visitorsTitle = NSLocalizedString("Visitors", comment: "All Time Stats 'Visitors' label")
        static let bestViewsEverTitle = NSLocalizedString("Best views ever", comment: "All Time Stats 'Best views ever' label")
    }

    struct MostPopularStats {
        static let bestDay = NSLocalizedString("Best Day", comment: "'Best Day' label for Most Popular stat.")
        static let bestHour = NSLocalizedString("Best Hour", comment: "'Best Hour' label for Most Popular stat.")
        static let viewPercentage = NSLocalizedString(
            "stats.insights.mostPopularCard.viewsNumber",
            value: "%1$@ of views",
            comment: "Label showing the percentage of views to a user's site which fall on a particular day."
        )
    }

    struct TodaysStats {
        static let viewsTitle = NSLocalizedString("Views", comment: "Today's Stats 'Views' label")
        static let visitorsTitle = NSLocalizedString("Visitors", comment: "Today's Stats 'Visitors' label")
        static let likesTitle = NSLocalizedString("Likes", comment: "Today's Stats 'Likes' label")
        static let commentsTitle = NSLocalizedString("Comments", comment: "Today's Stats 'Comments' label")
    }

    // MARK: - Create Table Rows

    func overviewTableRows() -> [any StatsHashableImmuTableRow] {
        let periodDate = self.lastRequestedDate

        return SiteStatsImmuTableRows.viewVisitorsImmuTableRows(mostRecentChartData,
                                                                selectedSegment: selectedViewsVisitorsSegment,
                                                                periodDate: periodDate,
                                                                siteStatsInsightsDelegate: siteStatsInsightsDelegate,
                                                                viewsAndVisitorsDelegate: viewsAndVisitorsDelegate)
    }

    func createAllTimeStatsRows() -> [StatsTwoColumnRowData] {
        guard let allTimeInsight = insightsStore.getAllTimeStats() else {
            return []
        }

        let totalCounts = allTimeInsight.viewsCount +
                          allTimeInsight.visitorsCount +
                          allTimeInsight.postsCount +
                          allTimeInsight.bestViewsPerDayCount

        guard totalCounts > 0 else {
            return []
        }

        var dataRows = [StatsTwoColumnRowData]()

        dataRows.append(StatsTwoColumnRowData.init(leftColumnName: AllTimeStats.viewsTitle,
                                                   leftColumnData: allTimeInsight.viewsCount.abbreviatedString(),
                                                   rightColumnName: AllTimeStats.visitorsTitle,
                                                   rightColumnData: allTimeInsight.visitorsCount.abbreviatedString()))

        dataRows.append(StatsTwoColumnRowData.init(leftColumnName: AllTimeStats.postsTitle,
                                                   leftColumnData: allTimeInsight.postsCount.abbreviatedString(),
                                                   rightColumnName: AllTimeStats.bestViewsEverTitle,
                                                   rightColumnData: allTimeInsight.bestViewsPerDayCount.abbreviatedString()))

        return dataRows
    }

    func createMostPopularStatsRowData() -> StatsMostPopularTimeData? {
        guard let mostPopularStats = insightsStore.getAnnualAndMostPopularTime(),
              let dayString = mostPopularStats.formattedMostPopularDay(),
              let timeString = mostPopularStats.formattedMostPopularTime(),
              mostPopularStats.mostPopularDayOfWeekPercentage > 0
        else {
            return nil
        }

        let dayPercentage = String(format: MostPopularStats.viewPercentage, mostPopularStats.mostPopularDayOfWeekPercentage.percentageString())
        let hourPercentage = String(format: MostPopularStats.viewPercentage, mostPopularStats.mostPopularHourPercentage.percentageString())

        return StatsMostPopularTimeData(mostPopularDayTitle: MostPopularStats.bestDay, mostPopularTimeTitle: MostPopularStats.bestHour, mostPopularDay: dayString, mostPopularTime: timeString.uppercased(), dayPercentage: dayPercentage, timePercentage: hourPercentage)
    }

    func createLikesTotalInsightsRow() -> StatsTotalInsightsData {
        return StatsTotalInsightsData.createTotalInsightsData(periodSummary: periodStore.getSummary(), insightsStore: insightsStore, statsSummaryType: .likes)
    }

    func createCommentsTotalInsightsRow() -> StatsTotalInsightsData {
        return StatsTotalInsightsData.createTotalInsightsData(periodSummary: periodStore.getSummary(), insightsStore: insightsStore, statsSummaryType: .comments)
    }

    func createFollowerTotalInsightsRow() -> StatsTotalInsightsData {
        var data = StatsTotalInsightsData.followersCount(insightsStore: insightsStore)
        if data.count < Constants.followersGuideLimit {
            let guideText = NSLocalizedString("Commenting on other blogs is a great way to build attention and followers for your new site.",
                                              comment: "A tip displayed to the user in the stats section to help them gain more followers.")
            data.guideText = NSAttributedString(string: guideText)
        }
        return data
    }

    func createPublicizeRows() -> [StatsTotalRowData] {
        guard let services = insightsStore.getPublicize()?.publicizeServices else {
            return []
        }

        return services.map {
            return StatsTotalRowData(name: $0.name,
                                     data: $0.followers.abbreviatedString(),
                                     socialIconURL: $0.iconURL,
                                     statSection: .insightsPublicize)
        }
    }

    func createTodaysStatsRows() -> [StatsTwoColumnRowData] {
        guard let todaysStats = insightsStore.getTodaysStats() else {
            return []
        }

        let totalCounts = todaysStats.viewsCount +
                          todaysStats.visitorsCount +
                          todaysStats.likesCount +
                          todaysStats.commentsCount

        guard totalCounts > 0 else {
            return []
        }

        var dataRows = [StatsTwoColumnRowData]()

        dataRows.append(StatsTwoColumnRowData.init(leftColumnName: TodaysStats.viewsTitle,
                                                   leftColumnData: todaysStats.viewsCount.abbreviatedString(),
                                                   rightColumnName: TodaysStats.visitorsTitle,
                                                   rightColumnData: todaysStats.visitorsCount.abbreviatedString()))

        dataRows.append(StatsTwoColumnRowData.init(leftColumnName: TodaysStats.likesTitle,
                                                   leftColumnData: todaysStats.likesCount.abbreviatedString(),
                                                   rightColumnName: TodaysStats.commentsTitle,
                                                   rightColumnData: todaysStats.commentsCount.abbreviatedString()))

        return dataRows
    }

    func createPostingActivityRow() -> PostingActivityRow {
        let monthsData = insightsStore.getQuarterlyPostingActivity(from: Date())

        return PostingActivityRow(monthsData: monthsData, siteStatsInsightsDelegate: siteStatsInsightsDelegate, statSection: .insightsPostingActivity)
    }

    func createTagsAndCategoriesRows() -> [StatsTotalRowData] {
        guard let tagsAndCategories = insightsStore.getTopTagsAndCategories()?.topTagsAndCategories else {
            return []
        }

        return tagsAndCategories.map {
            let viewsCount = $0.viewsCount ?? 0

            return StatsTotalRowData(name: $0.name,
                                     data: viewsCount.abbreviatedString(),
                                     dataBarPercent: Float(viewsCount) / Float(tagsAndCategories.first?.viewsCount ?? 1),
                                     icon: StatsDataHelper.tagsAndCategoriesIconForKind($0.kind),
                                     showDisclosure: true,
                                     disclosureURL: $0.url,
                                     childRows: StatsDataHelper.childRowsForItems($0.children),
                                     statSection: .insightsTagsAndCategories)
        }
    }

    func createAnnualRows() -> [StatsTwoColumnRowData] {
        guard let annualInsights = insightsStore.getAnnualAndMostPopularTime()?.years?.last,
              annualInsights.totalPosts > 0 else {
            return []
        }

        var dataRows = [StatsTwoColumnRowData]()

        dataRows.append(StatsTwoColumnRowData.init(leftColumnName: AnnualSiteStats.year,
                                                   leftColumnData: annualInsights.year,
                                                   rightColumnName: AnnualSiteStats.totalPosts,
                                                   rightColumnData: annualInsights.totalPosts.abbreviatedString()))

        dataRows.append(StatsTwoColumnRowData.init(leftColumnName: AnnualSiteStats.totalComments,
                                                   leftColumnData: annualInsights.totalComments.abbreviatedString(),
                                                   rightColumnName: AnnualSiteStats.commentsPerPost,
                                                   rightColumnData: annualInsights.averageComments.abbreviatedString()))

        dataRows.append(StatsTwoColumnRowData.init(leftColumnName: AnnualSiteStats.totalLikes,
                                                   leftColumnData: annualInsights.totalLikes.abbreviatedString(),
                                                   rightColumnName: AnnualSiteStats.likesPerPost,
                                                   rightColumnData: annualInsights.averageLikes.abbreviatedString()))

        dataRows.append(StatsTwoColumnRowData.init(leftColumnName: AnnualSiteStats.totalWords,
                                                   leftColumnData: annualInsights.totalWords.abbreviatedString(),
                                                   rightColumnName: AnnualSiteStats.wordsPerPost,
                                                   rightColumnData: annualInsights.averageWords.abbreviatedString()))

        return dataRows

    }

    func createCommentsRow() -> TabbedTotalsStatsRow {
        return TabbedTotalsStatsRow(tabsData: [tabDataForCommentType(.insightsCommentsAuthors),
                                               tabDataForCommentType(.insightsCommentsPosts)],
                                    statSection: .insightsCommentsAuthors,
                                    siteStatsInsightsDelegate: siteStatsInsightsDelegate,
                                    showTotalCount: false)
    }

    func tabDataForCommentType(_ commentType: StatSection) -> TabData {
        let commentsInsight = insightsStore.getTopCommentsInsight()

        var rowItems: [StatsTotalRowData] = []

        // Ref: https://github.com/wordpress-mobile/WordPress-iOS/issues/11713
        // For now, don't show `View more` for Insights Comments.
        // To accomplish this, return only the max number of rows displayed on the Insights card,
        // as `View more` is added if the number of rows exceeds the max.

        switch commentType {
        case .insightsCommentsAuthors:
            let authors = commentsInsight?.topAuthors.prefix(StatsDataHelper.maxRowsToDisplay) ?? []
            rowItems = authors.map {
                StatsTotalRowData(name: $0.name,
                                  data: $0.commentCount.abbreviatedString(),
                                  userIconURL: $0.iconURL,
                                  showDisclosure: false,
                                  statSection: .insightsCommentsAuthors)
            }
        case .insightsCommentsPosts:
            let posts = commentsInsight?.topPosts.prefix(StatsDataHelper.maxRowsToDisplay) ?? []
            rowItems = posts.map {
                StatsTotalRowData(name: $0.name,
                                  data: $0.commentCount.abbreviatedString(),
                                  showDisclosure: true,
                                  disclosureURL: $0.postURL,
                                  statSection: .insightsCommentsPosts)
            }
        default:
            break
        }

        return TabData(tabTitle: commentType.tabTitle,
                       itemSubtitle: commentType.itemSubtitle,
                       dataSubtitle: commentType.dataSubtitle,
                       dataRows: rowItems)
    }

    func createFollowersRow() -> TabbedTotalsStatsRow {
        return TabbedTotalsStatsRow(tabsData: [tabDataForFollowerType(.insightsFollowersWordPress),
                                               tabDataForFollowerType(.insightsFollowersEmail)],
                                    statSection: .insightsFollowersWordPress,
                                    siteStatsInsightsDelegate: siteStatsInsightsDelegate,
                                    showTotalCount: false)
    }

    func tabDataForFollowerType(_ followerType: StatSection) -> TabData {
        let tabTitle = followerType.tabTitle
        var followers: [StatsFollower]?
        var totalFollowers: Int?

        switch followerType {
        case .insightsFollowersWordPress:
            followers = insightsStore.getDotComFollowers()?.topDotComFollowers
            totalFollowers = insightsStore.getDotComFollowers()?.dotComFollowersCount
        case .insightsFollowersEmail:
            followers = insightsStore.getEmailFollowers()?.topEmailFollowers
            totalFollowers = insightsStore.getEmailFollowers()?.emailFollowersCount
        default:
            break
        }

        let totalCount = String(format: followerType.totalFollowers, (totalFollowers ?? 0).abbreviatedString())

        let followersData = followers?.compactMap {
            return StatsTotalRowData(name: $0.name,
                                     data: $0.subscribedDate.relativeStringInPast(),
                                     userIconURL: $0.avatarURL,
                                     statSection: followerType)
        }

        return TabData(tabTitle: tabTitle,
                       itemSubtitle: "",
                       dataSubtitle: "",
                       totalCount: totalCount,
                       dataRows: followersData ?? [])
    }
}

extension SiteStatsInsightsViewModel: AsyncBlocksLoadable {
    typealias RowType = InsightType

    var currentStore: StatsInsightsStore {
        return insightsStore
    }

    /// Splits the SummaryData into an array of 2 weeks, one for the current week and one for the previous week
    ///
    /// - Parameters:
    ///     - statsSummaryTimeIntervalData: summarydata to split
    ///     - periodEndDate: when the current period is not nil it will be used to pad forward until this date
    /// - Returns: an array of 2 weeks
    ///
    public static func splitStatsSummaryTimeIntervalData(_ statsSummaryTimeIntervalData: StatsSummaryTimeIntervalData, periodEndDate: Date? = nil) ->
            [StatsSummaryTimeIntervalDataAsAWeek] {

        var summaryData = statsSummaryTimeIntervalData.summaryData

        if let periodEndDate {
            summaryData = splitStatsSummaryTimeIntervalDataPadForward(statsSummaryTimeIntervalData, periodEndDate: periodEndDate)
        }

        return splitStatsSummaryData(summaryData)
    }

    /// When a periodEndDate is defined we pad forward the data to match the weeks view user experience on WordPress.com
    ///
    public static func splitStatsSummaryTimeIntervalDataPadForward(_ statsSummaryTimeIntervalData: StatsSummaryTimeIntervalData, periodEndDate: Date) ->
            [StatsSummaryData] {
        var summaryData = statsSummaryTimeIntervalData.summaryData
        let daysElapsedSincePeriodEndDate = Calendar.autoupdatingCurrent.dateComponents([.day], from: statsSummaryTimeIntervalData.periodEndDate, to: periodEndDate).day ?? 0
        if daysElapsedSincePeriodEndDate > 0 {
            for i in 1...daysElapsedSincePeriodEndDate {
                if let date = Calendar.autoupdatingCurrent.date(byAdding: .day, value: i, to: statsSummaryTimeIntervalData.periodEndDate) {
                    summaryData.append(StatsSummaryData(period: .day,
                                                        periodStartDate: date,
                                                        viewsCount: 0,
                                                        visitorsCount: 0,
                                                        likesCount: 0,
                                                        commentsCount: 0))
                }
            }
        }

        return summaryData
    }

    public static func splitStatsSummaryData(_ summaryData: [StatsSummaryData]) -> [StatsSummaryTimeIntervalDataAsAWeek] {
        var summaryData = summaryData

        switch summaryData.count {
        case let count where count == Constants.fourteenDays:
            // normal case api returns 14 rows
            return createStatsSummaryTimeIntervalDataAsAWeeks(summaryData: Array(summaryData[0..<Constants.fourteenDays]))
        case let count where count > Constants.fourteenDays:
            // when more than 14 rows we take the last 14 rows for most recent data
            return createStatsSummaryTimeIntervalDataAsAWeeks(summaryData: Array(summaryData[count - Constants.fourteenDays..<count]))
        case let count where count < Constants.fourteenDays:
            // when 0 to 14 rows presume the user could be new / doesn't have enough data.  Pad 0's to prev week
            summaryData.reverse()

            guard var date = summaryData.last?.periodStartDate else {
                return []
            }

            while summaryData.count < Constants.fourteenDays {
                if let newPeriodStartDate = Calendar.autoupdatingCurrent.date(byAdding: .day, value: -1, to: date) {
                    date = newPeriodStartDate
                    summaryData.append(StatsSummaryData(period: .day,
                                                        periodStartDate: newPeriodStartDate,
                                                        viewsCount: 0,
                                                        visitorsCount: 0,
                                                        likesCount: 0,
                                                        commentsCount: 0))
                }
            }

            summaryData.reverse()
            return createStatsSummaryTimeIntervalDataAsAWeeks(summaryData: summaryData)
        default:
            return []
        }
    }

    public static func createStatsSummaryTimeIntervalDataAsAWeeks(summaryData: [StatsSummaryData]) -> [StatsSummaryTimeIntervalDataAsAWeek] {
        let half = 7
        let prevWeekData = summaryData[0 ..< half]
        let prevWeekTimeIntervalData = StatsSummaryTimeIntervalData(
            period: .day,
            unit: .day,
            periodEndDate: prevWeekData.last!.periodStartDate,
            summaryData: Array(prevWeekData)
        )

        let thisWeekData = summaryData[half ..< Constants.fourteenDays]
        let thisWeekTimeIntervalData = StatsSummaryTimeIntervalData(
            period: .day,
            unit: .day,
            periodEndDate: thisWeekData.last!.periodStartDate,
            summaryData: Array(thisWeekData)
        )

        return [StatsSummaryTimeIntervalDataAsAWeek.thisWeek(data: thisWeekTimeIntervalData),
                StatsSummaryTimeIntervalDataAsAWeek.prevWeek(data: prevWeekTimeIntervalData)]
    }

    enum Constants {
        static let fourteenDays = 14

        // The followers guide will be displayed if a user has < 2 users
        static let followersGuideLimit = 2
    }
}
