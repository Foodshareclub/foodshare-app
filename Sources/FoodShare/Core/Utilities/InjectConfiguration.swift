//
//  InjectConfiguration.swift
//  Foodshare
//
//  Hot reload configuration using Inject library.
//  Only active in DEBUG builds - zero overhead in release.
//
//  Usage:
//  3. Press Ctrl+= in Xcode to trigger hot reload after saving
//

import SwiftUI

#if DEBUG

    /// View modifier that enables hot reload for any SwiftUI view
    public struct HotReloadModifier: ViewModifier {
        public func body(content: Content) -> some View {
            content
        }
    }

    extension View {
        /// Enable hot reload for this view in DEBUG builds
        /// Usage: MyView().hotReload()
        public func hotReload() -> some View {
            modifier(HotReloadModifier())
        }
    }

#else

    // No-op in release builds
    extension View {
        public func hotReload() -> some View {
            self
        }
    }

#endif
