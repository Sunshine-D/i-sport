import XCTest
@testable import MealDomain

final class MealTests: XCTestCase {
    func testConsumedFractionUpdatesMealTotal() throws {
        let rice = FoodItem(name: "米饭", grams: 150, kcal: 175, consumedFraction: 0.5)
        let meal = Meal(foods: [rice, FoodItem(name: "鸡肉", grams: 120, kcal: 240)])
        try meal.validate(); XCTAssertEqual(meal.totalKcal, 327.5)
        XCTAssertEqual(rice.effectiveGrams, 75)
    }
    func testInvalidFractionAndNonFiniteAreRejected() {
        XCTAssertThrowsError(try FoodItem(name: "饭", grams: 100, kcal: 100, consumedFraction: 1.1).validate())
        XCTAssertThrowsError(try FoodItem(name: "饭", grams: .infinity, kcal: 100).validate())
        XCTAssertThrowsError(try FoodItem(name: "", grams: 100, kcal: 100).validate())
    }
    func testUnknownNutrientsRemainUnknown() {
        let meal = Meal(foods: [FoodItem(name: "菜", grams: 100, kcal: 110)])
        XCTAssertNil(meal.nutrient(\.protein))
    }
    func testStructuredVisionResponseIsParsed() throws {
        let foods = try RecognitionParser.parse("""
        ```json
        {"foods":[{"name":"米饭","grams":150,"kcal":175,"protein":null}]}
        ```
        """)
        XCTAssertEqual(foods.count, 1); XCTAssertEqual(foods[0].kcal, 175)
    }
    func testInvalidAndEmptyModelResponsesAreRejected() {
        XCTAssertThrowsError(try RecognitionParser.parse("{\"foods\":[]}"))
        XCTAssertThrowsError(try RecognitionParser.parse("{\"foods\":[{\"name\":\"饭\",\"grams\":-1,\"kcal\":12}]}"))
    }
    func testDuplicateFoodIdentityIsRejected() {
        let rice = FoodItem(name: "米饭", grams: 150, kcal: 175)
        XCTAssertThrowsError(try Meal(foods: [rice, rice]).validate())
    }
    func testCodableRoundTripPreservesIdentityAndVersion() throws {
        var meal = Meal(foods: [FoodItem(name: "饭", grams: 100, kcal: 120)])
        meal.version = 4
        let decoded = try JSONDecoder().decode(Meal.self, from: JSONEncoder().encode(meal))
        XCTAssertEqual(decoded, meal)
    }
}
