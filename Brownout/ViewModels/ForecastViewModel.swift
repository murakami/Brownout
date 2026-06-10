import Foundation
import SwiftUI

@MainActor
@Observable
final class ForecastViewModel {
    @ObservationIgnored
    @AppStorage("selectedAreaID") private var selectedAreaID: String = PowerArea.tokyo.id

    var selectedArea: PowerArea {
        get { PowerArea.all.first { $0.id == selectedAreaID } ?? .tokyo }
        set {
            selectedAreaID = newValue.id
            Task { await load() }
        }
    }

    var forecast: DailyForecast?
    var isLoading = false
    var error: ForecastError?

    func load(date: Date = .now) async {
        isLoading = true
        error = nil
        do {
            forecast = try await PowerForecastService.shared.fetchForecast(
                area: selectedArea, date: date
            )
        } catch let e as ForecastError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
        isLoading = false
    }
}
