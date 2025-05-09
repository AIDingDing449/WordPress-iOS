import Foundation

protocol HashableImmutableRow: ImmuTableRow, Hashable {}

extension HashableImmutableRow {
    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: type(of: self)))
    }
}

protocol StatsHashableImmuTableRow: HashableImmutableRow {
    var statSection: StatSection? { get }
}

extension StatsHashableImmuTableRow {
    /// The diffable data source relies on both the identity and the equality of the items it manages.
    /// The identity is determined by the item's hash, and equality is determined by whether the item's content has changed.
    /// If the content of an item is considered to have changed (even if its hash hasn't), the diffable data source may decide to reload that item.
    ///
    /// Calculate hash (identity) based on StatSection type and Row type
    /// If identity is equal particular cell reloads only if content changes
    func hash(into hasher: inout Hasher) {
        hasher.combine(statSection)
        hasher.combine(String(describing: type(of: self)))
    }
}

// MARK: - Helpers

struct AnyHashableSectionWithRows: Hashable {
    let rows: [AnyHashableImmuTableRow]
}

extension ImmuTableDiffableDataSourceSnapshot {
    mutating func addSection(_ rows: [any HashableImmutableRow]) {
        let rows = rows.map { AnyHashableImmuTableRow(immuTableRow: $0) }
        let section = AnyHashableSectionWithRows(rows: rows)
        appendSections([section])
        appendItems(rows, toSection: section)
    }

    static func singleSectionSnapshot(_ rows: [any HashableImmutableRow]) -> ImmuTableDiffableDataSourceSnapshot {
        var snapshot = ImmuTableDiffableDataSourceSnapshot()
        let rows = rows.map { AnyHashableImmuTableRow(immuTableRow: $0) }
        let section = AnyHashableSectionWithRows(rows: rows)
        snapshot.appendSections([section])
        snapshot.appendItems(rows, toSection: section)
        return snapshot
    }

    static func multiSectionSnapshot(_ rows: [any HashableImmutableRow]) -> ImmuTableDiffableDataSourceSnapshot {
        var snapshot = ImmuTableDiffableDataSourceSnapshot()
        let rows = rows.map { AnyHashableImmuTableRow(immuTableRow: $0) }
        for row in rows {
            let section = AnyHashableSectionWithRows(rows: [row])
            snapshot.appendSections([section])
            snapshot.appendItems([row], toSection: section)
        }
        return snapshot
    }
}
