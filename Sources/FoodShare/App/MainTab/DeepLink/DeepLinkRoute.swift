//
//  DeepLinkRoute.swift
//  Foodshare
//
//  Routes for deep-link navigation within the app
//


#if !SKIP
import Foundation

/// Routes for deep-link navigation
enum DeepLinkRoute: Hashable {
    case listing(Int)
    case forumPost(Int)
    case challenge(Int)
    case profile(UUID)
}

#endif
