import Foundation
import SwiftUI

enum TransactionKind: String, CaseIterable, Identifiable, Codable {
    case expense = "支出"
    case income = "收入"
    case transfer = "转账"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .expense: "arrow.down.circle.fill"
        case .income: "arrow.up.circle.fill"
        case .transfer: "arrow.left.arrow.right.circle.fill"
        }
    }

    var tintHex: String {
        switch self {
        case .expense: "#F178A6"
        case .income: "#57BFA1"
        case .transfer: "#F2A65A"
        }
    }
}

enum AccountKind: String, CaseIterable, Identifiable, Codable {
    case cash = "现金"
    case bank = "银行卡"
    case wallet = "电子钱包"
    case credit = "信用卡"
    case investment = "投资"
    case other = "其他"

    var id: String { rawValue }
}

enum AssetLiabilityKind: String, CaseIterable, Identifiable, Codable {
    case asset = "资产"
    case liability = "负债"

    var id: String { rawValue }
}

struct LedgerTransaction: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: TransactionKind
    var amountCents: Int
    var categoryID: UUID?
    var accountID: UUID
    var toAccountID: UUID?
    var date: Date
    var note: String
    var tags: [String]
    var attachmentIDs: [UUID]
    var isRefund: Bool
    var isReimbursed: Bool
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

struct LedgerCategory: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var symbolName: String
    var colorHex: String
    var kind: TransactionKind
    var sortOrder: Int
}

struct LedgerAccount: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var kind: AccountKind
    var openingBalanceCents: Int
    var colorHex: String
    var includeInNetWorth: Bool
}

struct LedgerBudget: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var monthKey: String
    var categoryID: UUID?
    var amountCents: Int
    var warningRatio: Double
    var isEnabled: Bool
}

struct AssetLiability: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var kind: AssetLiabilityKind
    var balanceCents: Int
    var colorHex: String
    var note: String
}

struct LedgerAttachment: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var localPath: String
    var ocrText: String
    var createdAt: Date = Date()
}

struct ImportResult: Identifiable {
    var id = UUID()
    var importedCount: Int
    var failedRows: [String]

    var summary: String {
        if failedRows.isEmpty {
            return "已导入 \(importedCount) 条记录。"
        }
        return "已导入 \(importedCount) 条记录，\(failedRows.count) 行需要检查。"
    }
}

struct CategorySpending: Identifiable, Hashable {
    var category: LedgerCategory
    var amountCents: Int

    var id: UUID {
        category.id
    }
}
