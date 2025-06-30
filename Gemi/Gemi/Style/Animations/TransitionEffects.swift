//
//  TransitionEffects.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

// MARK: - Custom Transitions

extension AnyTransition {
    static var slideAndFade: AnyTransition {
        .asymmetric(
            insertion: .slide.combined(with: .opacity),
            removal: .opacity.animation(DesignSystem.Animation.quick)
        )
    }
    
    static var scaleAndFade: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }
    
    static var moveAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
    
    static func slideIn(from edge: Edge) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: edge).combined(with: .opacity),
            removal: .opacity
        )
    }
    
    static var cardInsertion: AnyTransition {
        .modifier(
            active: CardInsertionModifier(isActive: true),
            identity: CardInsertionModifier(isActive: false)
        )
    }
    
    static var cardDeletion: AnyTransition {
        .modifier(
            active: CardDeletionModifier(isActive: true),
            identity: CardDeletionModifier(isActive: false)
        )
    }
}

// MARK: - Card Transition Modifiers

struct CardInsertionModifier: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 0.8 : 1)
            .opacity(isActive ? 0 : 1)
            .offset(y: isActive ? 20 : 0)
            .blur(radius: isActive ? 2 : 0)
    }
}

struct CardDeletionModifier: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 0.9 : 1)
            .opacity(isActive ? 0 : 1)
            .offset(x: isActive ? 100 : 0)
            .rotationEffect(.degrees(isActive ? 5 : 0))
    }
}

// MARK: - Navigation Transitions

struct NavigationTransition: ViewModifier {
    let isPresented: Bool
    let direction: NavigationDirection
    
    enum NavigationDirection {
        case forward, backward, up, down
    }
    
    private var offset: CGSize {
        guard !isPresented else { return .zero }
        
        switch direction {
        case .forward:
            return CGSize(width: 50, height: 0)
        case .backward:
            return CGSize(width: -50, height: 0)
        case .up:
            return CGSize(width: 0, height: -50)
        case .down:
            return CGSize(width: 0, height: 50)
        }
    }
    
    func body(content: Content) -> some View {
        content
            .offset(offset)
            .opacity(isPresented ? 1 : 0)
            .animation(DesignSystem.Animation.standard, value: isPresented)
    }
}

// MARK: - Page Transition

struct PageTransition: ViewModifier {
    let page: Int
    let currentPage: Int
    
    private var offset: CGFloat {
        CGFloat(page - currentPage) * NSScreen.main!.frame.width
    }
    
    private var opacity: Double {
        page == currentPage ? 1 : 0.3
    }
    
    private var scale: Double {
        page == currentPage ? 1 : 0.95
    }
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(opacity)
            .scaleEffect(scale)
            .animation(DesignSystem.Animation.smooth, value: currentPage)
    }
}

// MARK: - Crossfade Transition

struct CrossfadeTransition<T: Equatable & Hashable>: ViewModifier {
    let value: T
    let animation: Animation
    
    init(value: T, animation: Animation = DesignSystem.Animation.standard) {
        self.value = value
        self.animation = animation
    }
    
    func body(content: Content) -> some View {
        content
            .id(value)
            .transition(.opacity)
            .animation(animation, value: value)
    }
}

// MARK: - Matched Geometry Transitions

struct MatchedGeometryTransition: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    let isSource: Bool
    
    func body(content: Content) -> some View {
        if isSource {
            content
                .matchedGeometryEffect(id: id, in: namespace, isSource: true)
        } else {
            content
                .matchedGeometryEffect(id: id, in: namespace, isSource: false)
        }
    }
}

// MARK: - View Extensions

extension View {
    func navigationTransition(isPresented: Bool, direction: NavigationTransition.NavigationDirection) -> some View {
        modifier(NavigationTransition(isPresented: isPresented, direction: direction))
    }
    
    func pageTransition(page: Int, currentPage: Int) -> some View {
        modifier(PageTransition(page: page, currentPage: currentPage))
    }
    
    func crossfade<T: Equatable & Hashable>(on value: T, animation: Animation = DesignSystem.Animation.standard) -> some View {
        modifier(CrossfadeTransition(value: value, animation: animation))
    }
    
    func matchedTransition(id: String, namespace: Namespace.ID, isSource: Bool = true) -> some View {
        modifier(MatchedGeometryTransition(id: id, namespace: namespace, isSource: isSource))
    }
}