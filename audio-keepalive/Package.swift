// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "AudioKeepalive",
    targets: [
        .executableTarget(
            name: "AudioKeepalive",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        )
    ]
)
