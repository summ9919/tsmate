import SwiftUI

struct AppView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar(model: model)

            ScrollView {
                VStack(spacing: 14) {
                    StatusCardGrid(cards: model.statusCards)
                    DeviceListCard(model: model)
                    PolicyCard(model: model)
                    ModeSelector(model: model)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }

            LogConsole()
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case .settings:
                SettingsView()
            case .device(let device):
                DeviceDetailView(model: model, device: device)
            case .menu:
                MenuSheet(model: model)
            case .account:
                AccountSheet(model: model)
            }
        }
    }
}
