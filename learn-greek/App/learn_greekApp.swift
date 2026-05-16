//
//  learn_greekApp.swift
//  learn-greek
//
//  Created by Leonidas von Bothmer on 30.04.26.
//

import SwiftUI

@main
struct learn_greekApp: App {
    var body: some Scene {
        WindowGroup {
            AppLaunchView()
        }
    }
}

private struct AppLaunchView: View {
    @State private var isSplashVisible = true
    @State private var launchCardFrame: CGRect = .zero

    var body: some View {
        ZStack {
            ReviewView()
                .onPreferenceChange(LaunchCardFramePreferenceKey.self) { frame in
                    launchCardFrame = frame
                }

            if isSplashVisible {
                SplashScreenView(targetCardFrame: launchCardFrame)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .coordinateSpace(name: "launchSpace")
        .task {
            try? await Task.sleep(for: .seconds(1.09))

            withAnimation(.easeInOut(duration: 0.09)) {
                isSplashVisible = false
            }
        }
    }
}
