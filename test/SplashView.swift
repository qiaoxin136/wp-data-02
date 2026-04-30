//
//  SplashView.swift
//  test
//
//  Created by Xin Qiao on 4/16/26.
//

import SwiftUI

struct SplashView: View {
    @Binding var isActive: Bool

    @State private var pinScale: CGFloat = 0.4
    @State private var pinOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var backgroundOpacity: Double = 1

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.38, blue: 0.90),
                         Color(red: 0.05, green: 0.22, blue: 0.60)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Logo mark
                AppLogoView(size: 118, cornerRadius: 28, animated: true)
                    .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
                    .scaleEffect(pinScale)
                    .opacity(pinOpacity)

                Spacer().frame(height: 28)

                // App name
                Text("MapExplorer")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(textOpacity)

                Spacer().frame(height: 8)

                // Tagline
                Text("Explore the world around you")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .opacity(taglineOpacity)
            }
        }
        .opacity(backgroundOpacity)
        .onAppear {
            // Logo bounces in
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
                pinScale = 1.0
                pinOpacity = 1
            }
            // Title fades in
            withAnimation(.easeOut(duration: 0.4).delay(0.35)) {
                textOpacity = 1
            }
            // Tagline fades in
            withAnimation(.easeOut(duration: 0.4).delay(0.55)) {
                taglineOpacity = 1
            }
            // Fade out and hand off to map
            withAnimation(.easeIn(duration: 0.45).delay(2.0)) {
                backgroundOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.45) {
                isActive = false
            }
        }
    }
}

#Preview {
    SplashView(isActive: .constant(true))
}
