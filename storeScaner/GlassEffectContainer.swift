//
//  GlassEffectContainer.swift
//  storeScaner
//
//  Created by Jacek Kałużny on 21/06/2025.
//


//
//  SwiftCompatibility.swift
//  OgienBilety
//
//  Created by Jacek Kałużny on 13/06/2025.
//

import Foundation
#if compiler(<6.2) // Only for compilers older than Xcode 26 (iOS 26 SDK)

// Dummy view modifier and container for compatibility

import SwiftUI

// Empty version of GlassEffectContainer
struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content
    
    init(spacing: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        content()
    }
}

// Dummy modifiers
extension View {
    func glassEffect(glass:AnyObject, in:AnyObject = 5, isEnabled:Bool = true) -> some View { self }
    func glassEffectID<V>(_ value: V, in namespace: Namespace.ID) -> some View { self }
    func glassEffectUnion(id: String, namespace: Namespace.ID) -> some View { self }
}

#endif
import SwiftUI

extension View {
    @ViewBuilder
    func matchedTransitionSourceCompat(id: String, namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func navigationTransitionCompat(id: String, namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
