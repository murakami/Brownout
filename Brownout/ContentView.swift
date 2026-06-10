import SwiftUI

struct ContentView: View {
    @State private var viewModel = ForecastViewModel()
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error {
                    ErrorView(area: viewModel.selectedArea, error: error) {
                        Task { await viewModel.load() }
                    }
                } else if let forecast = viewModel.forecast {
                    ScrollView {
                        VStack(spacing: 20) {
                            UsageRateView(forecast: forecast)
                            DemandChartView(forecast: forecast)
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await viewModel.load()
                    }
                }
            }
            .navigationTitle("Power Forecast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AreaPickerView(selectedArea: $viewModel.selectedArea)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("", systemImage: "info.circle") {
                        showAbout = true
                    }
                    Button("", systemImage: "arrow.clockwise") {
                        Task { await viewModel.load() }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    ContentView()
}
