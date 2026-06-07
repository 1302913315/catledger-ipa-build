import Charts
import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var store: LedgerStore

    var body: some View {
        CatPage(title: "统计报表", subtitle: "看看钱都去了哪里") {
            HStack(spacing: 12) {
                MetricTile(
                    title: "本月支出",
                    value: moneyText(store.monthlyExpenseCents),
                    symbolName: "cart.fill",
                    tint: .catRose
                )
                MetricTile(
                    title: "结余",
                    value: moneyText(store.monthBalanceCents),
                    symbolName: "sparkle.magnifyingglass",
                    tint: .catMint
                )
            }

            trendChart
            categoryChart
            categoryRanking
            accountSnapshot
        }
    }

    private var trendChart: some View {
        CatCard {
            SectionHeader("近 7 日趋势")
            Chart {
                ForEach(Array(store.trend().enumerated()), id: \.offset) { _, item in
                    BarMark(
                        x: .value("日期", Date.shortDayFormatter.string(from: item.0)),
                        y: .value("收入", Double(item.1) / 100)
                    )
                    .foregroundStyle(Color.catMint)

                    BarMark(
                        x: .value("日期", Date.shortDayFormatter.string(from: item.0)),
                        y: .value("支出", Double(item.2) / 100)
                    )
                    .foregroundStyle(Color.catRose)
                }
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
    }

    private var categoryChart: some View {
        CatCard {
            SectionHeader("分类占比")
            let data = store.expensesByCategory()

            if data.isEmpty {
                Text("本月还没有支出记录。")
                    .font(.subheadline)
                    .foregroundStyle(Color.catSubtext)
            } else {
                Chart(data) { item in
                    SectorMark(
                        angle: .value("金额", item.amountCents),
                        innerRadius: .ratio(0.58),
                        angularInset: 1.5
                    )
                    .foregroundStyle(Color(hex: item.category.colorHex))
                }
                .frame(height: 230)
            }
        }
    }

    private var categoryRanking: some View {
        CatCard {
            SectionHeader("消费排行榜")
            let data = store.expensesByCategory()

            if data.isEmpty {
                Text("记录几笔支出后，这里会出现排行榜。")
                    .font(.subheadline)
                    .foregroundStyle(Color.catSubtext)
            } else {
                ForEach(data.prefix(6)) { item in
                    HStack {
                        Label(item.category.name, systemImage: item.category.symbolName)
                            .foregroundStyle(Color.catInk)
                        Spacer()
                        Text(moneyText(item.amountCents))
                            .font(.headline)
                            .foregroundStyle(Color(hex: item.category.colorHex))
                    }
                    ProgressView(value: Double(item.amountCents), total: Double(max(data.first?.amountCents ?? item.amountCents, 1)))
                        .tint(Color(hex: item.category.colorHex))
                }
            }
        }
    }

    private var accountSnapshot: some View {
        CatCard {
            SectionHeader("账户余额")
            ForEach(store.accounts) { account in
                HStack {
                    Circle()
                        .fill(Color(hex: account.colorHex))
                        .frame(width: 10, height: 10)
                    Text(account.name)
                        .foregroundStyle(Color.catInk)
                    Spacer()
                    Text(moneyText(store.balance(for: account.id)))
                        .font(.headline)
                        .foregroundStyle(Color.catInk)
                }
            }
        }
    }
}
