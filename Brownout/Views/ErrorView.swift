import SwiftUI

struct ErrorView: View {
    let area: PowerArea
    let error: ForecastError
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            VStack(spacing: 8) {
                Text("Failed to fetch data")
                    .font(.headline)
                Text(error.localizedDescription ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button("Retry") { retry() }
                    .buttonStyle(.borderedProminent)

                Link("Open official website", destination: area.websiteURL)
                    .font(.caption)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ErrorView(area: .tokyo, error: .noData) { }
        .background(.black)
        .colorScheme(.dark)
}
