// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "MealDomain", products: [.library(name: "MealDomain", targets: ["MealDomain"])],
    targets: [.target(name: "MealDomain", path: "LightMeal/Core", exclude: ["MealStore.swift"]),
              .testTarget(name: "MealDomainTests", dependencies: ["MealDomain"], path: "Tests")])
