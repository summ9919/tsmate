import SwiftUI

struct AppView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar(model: model)

            ScrollView {
                VStack(spacing: 12) {
                    StatusCardGrid(cards: model.statusCards)
                    DeviceListCard(model: model)
                    PolicyCard(model: model)
                    ModeSelector(model: model)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }

            LogConsole()
                .frame(height: 230)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .sheet(item: $model.sheet) { item in
            if case .device(let device) = item {
                DeviceDetailView(model: model, device: device)
            } else {
                SettingsView()
            }
        }
    }
}
