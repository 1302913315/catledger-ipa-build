import SwiftUI

@main
struct CatLedgerApp: App {
    @StateObject private var store = LedgerStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("首页", systemImage: "house.fill")
            }

            NavigationStack {
                TransactionsView()
            }
            .tabItem {
                Label("明细", systemImage: "list.bullet.rectangle.portrait.fill")
            }

            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("统计", systemImage: "chart.pie.fill")
            }

            NavigationStack {
                BudgetView()
            }
            .tabItem {
                Label("预算", systemImage: "target")
            }

            NavigationStack {
                ToolsView()
            }
            .tabItem {
                Label("工具", systemImage: "wand.and.stars")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("我的", systemImage: "person.crop.circle.fill")
            }
        }
        .tint(.catRose)
    }
}
