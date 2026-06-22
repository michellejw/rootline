// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MycogridSolver",
    targets: [
        .target(name: "MycogridSolver"),
        .executableTarget(name: "mycogrid-validate", dependencies: ["MycogridSolver"]),
        .executableTarget(name: "mycogrid-generate", dependencies: ["MycogridSolver"]),
        .testTarget(name: "MycogridSolverTests", dependencies: ["MycogridSolver"]),
    ]
)
