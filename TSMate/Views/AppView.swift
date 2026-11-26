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
                    PolicyCard()
                    ModeSelector(model: model)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }

            LogConsole(model: model)
                .frame(height: 230)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}
