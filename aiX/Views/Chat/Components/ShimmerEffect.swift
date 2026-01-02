//
//  ShimmerEffect.swift
//  aizen
//
//  Shimmer animation effect for loading states
//

import SwiftUI

struct ShimmerEffect: ViewModifier {
    private let animation: Animation
    private let gradient: Gradient
    private let min: CGFloat
    private let max: CGFloat

    @State private var isInitialState = true
    @Environment(\.layoutDirection) private var layoutDirection

    init(
        animation: Animation = .linear(duration: 1.5).delay(0.25).repeatForever(autoreverses: false),
        gradient: Gradient = Gradient(colors: [
            .black.opacity(0.3),
            .black,
            .black.opacity(0.3)
        ]),
        bandSize: CGFloat = 0.3
    ) {
        self.animation = animation
        self.gradient = gradient
        self.min = 0 - bandSize
        self.max = 1 + bandSize
    }

    var startPoint: UnitPoint {
        if layoutDirection == .rightToLeft {
            isInitialState ? UnitPoint(x: max, y: min) : UnitPoint(x: 0, y: 1)
        } else {
            isInitialState ? UnitPoint(x: min, y: min) : UnitPoint(x: 1, y: 1)
        }
    }

    var endPoint: UnitPoint {
        if layoutDirection == .rightToLeft {
            isInitialState ? UnitPoint(x: 1, y: 0) : UnitPoint(x: min, y: max)
        } else {
            isInitialState ? UnitPoint(x: 0, y: 0) : UnitPoint(x: max, y: max)
        }
    }

    func body(content: Content) -> some View {
        content
            .mask(
                LinearGradient(
                    gradient: gradient,
                    startPoint: startPoint,
                    endPoint: endPoint
                )
            )
            .animation(animation, value: isInitialState)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    isInitialState = false
                }
            }
    }
}
