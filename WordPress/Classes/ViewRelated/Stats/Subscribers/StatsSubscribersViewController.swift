import Foundation
import Combine

final class StatsSubscribersViewController: SiteStatsBaseTableViewController {
    private let viewModel: StatsSubscribersViewModel
    private var cancellables: Set<AnyCancellable> = []

    private lazy var tableHandler: ImmuTableDiffableViewHandler = {
        return ImmuTableDiffableViewHandler(takeOver: self, with: nil)
    }()

    init(viewModel: StatsSubscribersViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        tableStyle = .insetGrouped
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel.viewMoreDelegate = self
        ImmuTable.registerRows(tableRowTypes(), tableView: tableView)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        addObservers()
        viewModel.addObservers()
        viewModel.refreshData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        removeObservers()
        viewModel.removeObservers()
    }

    private func addObservers() {
        viewModel.tableViewSnapshot
            .sink { [weak self] snapshot in
                guard let self else { return }

                self.tableHandler.diffableDataSource.apply(snapshot, animatingDifferences: false)
            }
            .store(in: &cancellables)
    }

    private func removeObservers() {
        cancellables = []
    }

    @objc private func refreshData() {
        viewModel.refreshData()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshControl.endRefreshing()
        }
    }

    // MARK: - Table View

    func tableRowTypes() -> [ImmuTableRow.Type] {
        return [
            TopTotalsPeriodStatsRow.self,
            StatsGhostTopImmutableRow.self,
            StatsErrorRow.self
        ]
    }
}

extension StatsSubscribersViewController: SiteStatsPeriodDelegate {
    func viewMoreSelectedForStatSection(_ statSection: StatSection) {
        // TODO
        DDLogInfo("\(statSection) selected")
    }
}