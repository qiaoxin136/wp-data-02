//
//  testApp.swift
//  test
//
//  Created by Xin Qiao on 4/16/26.
//

import SwiftUI
import GoogleMaps

@main
struct testApp: App {
    // @State holds the observable object so SwiftUI owns the lifecycle
    // and properly tracks all @Observable property accesses throughout the tree.
    @State private var auth = AuthService.shared

    init() {
        GMSServices.provideAPIKey("AIzaSyBmHgrFL1iNWENz-_qz2nsSanVAvheJtT4")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
        }
    }
}

private struct RootView: View {
    // @Environment ensures SwiftUI's observation tracking is properly wired.
    @Environment(AuthService.self) private var auth
    @State private var showSplash = true

    var body: some View {
        if showSplash {
            SplashView(isActive: $showSplash)
        } else if auth.isSignedIn {
            ContentView()
        } else {
            LoginView()
        }
    }
}
