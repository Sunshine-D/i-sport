import SwiftUI

@main struct LightMealApp: App {
    @StateObject private var store = MealStore()
    @StateObject private var health = HealthService()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).environmentObject(health)
                .tint(.mealOrange)
        }
    }
}
