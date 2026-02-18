//
//  TranslationKeys.swift
//  Foodshare
//
//  Type-safe translation keys for compile-time validation.
//  Generated from en.json structure.
//


#if !SKIP
import Foundation

// MARK: - Type-Safe Translation Keys

/// Type-safe translation key namespace.
/// Usage: `t.t(TK.Common.loading)` instead of `t.t("common.loading")`
public enum TK {
    // MARK: - Common
    public enum Common {
        public static let ok = "common.ok"
        public static let yes = "common.yes"
        public static let no = "common.no"
        public static let cancel = "common.cancel"
        public static let done = "common.done"
        public static let save = "common.save"
        public static let edit = "common.edit"
        public static let delete = "common.delete"
        public static let close = "common.close"
        public static let back = "common.back"
        public static let next = "common.next"
        public static let retry = "common.retry"
        public static let loading = "common.loading"
        public static let refresh = "common.refresh"
        public static let search = "common.search"
        public static let share = "common.share"
        public static let report = "common.report"
        public static let submit = "common.submit"
        public static let confirm = "common.confirm"
        public static let tryAgain = "common.try_again"
        public static let loadMore = "common.load_more"
        public static let showMore = "common.show_more"
        public static let showLess = "common.show_less"
        public static let seeAll = "common.see_all"
        public static let viewAll = "common.view_all"
        public static let clearAll = "common.clear_all"
        public static let noResults = "common.no_results"
        public static let unknown = "common.unknown"
        public static let success = "common.success"
        public static let error = "common.error._title"
        public static let errorTitle = "common.error.title"
        public static let errorUnknown = "common.error.unknown"
        public static let somethingWentWrong = "common.something_went_wrong"
    }

    // MARK: - Tabs
    public enum Tabs {
        public static let explore = "tabs.explore"
        public static let chats = "tabs.chats"
        public static let forum = "tabs.forum"
        public static let profile = "tabs.profile"
        public static let challenges = "tabs.challenges"
    }

    // MARK: - Auth
    public enum Auth {
        public static let signIn = "auth.sign_in"
        public static let signUp = "auth.sign_up"
        public static let signOut = "auth.sign_out"
        public static let password = "auth.password"
        public static let email = "common.email"
        public static let forgotPassword = "auth.forgot_password"
        public static let resetPassword = "auth.reset_password"
        public static let createAccount = "auth.create_account"
        public static let continueApple = "auth.continue_apple"
        public static let continueGoogle = "auth.continue_google"
        public static let noAccount = "auth.no_account"
        public static let alreadyHaveAccount = "auth.already_have_account"
    }

    // MARK: - Feed
    public enum Feed {
        public static let trending = "feed.trending"
        public static let shareNow = "feed.share_now"
        public static let noListings = "feed.no_listings"
        public static let noListingsTitle = "feed.no_listings_title"
        public static let loadingTitle = "feed.loading_title"
        public static let loadingSubtitle = "feed.loading_subtitle"
        public static let locationRequired = "feed.location_required"
        public static let beFirstToShare = "feed.be_first_to_share"
    }

    // MARK: - Listing
    public enum Listing {
        public static let details = "listing.details"
        public static let reviews = "listing.reviews"
        public static let arranged = "listing.arranged"
        public static let expiring = "listing.expiring"
        public static let noImages = "listing.no_images"
        public static let directions = "listing.directions"
        public static let editTitle = "listing.edit_title"
        public static let createTitle = "listing.create_title"
        public static let reportItem = "listing.report_item"
        public static let contactSharer = "listing.contact_sharer"
        public static let pickupLocation = "listing.pickup_location"
        public static let imageUnavailable = "listing.image_unavailable"
    }

    // MARK: - Profile
    public enum Profile {
        public static let title = "profile.title"
        public static let share = "profile.share"
        public static let badges = "profile.badges"
        public static let settings = "profile.settings"
        public static let signOut = "profile.sign_out"
        public static let signOutConfirm = "profile.sign_out_confirm"
        public static let editProfile = "profile.edit_profile"
        public static let myListings = "profile.my_listings"
        public static let notifications = "profile.notifications"
        public static let deleteAccount = "profile.delete_account"
        public static let inviteFriends = "profile.invite_friends"
    }

    // MARK: - Settings
    public enum Settings {
        public static let title = "settings.title"
        public static let account = "settings.account"
        public static let language = "settings.language._title"
        public static let privacy = "settings.privacy._title"
        public static let notifications = "settings.notifications._title"
        public static let security = "settings.security._title"
        public static let signOut = "settings.sign_out"
        public static let signOutConfirm = "settings.sign_out_confirm"
        public static let blockedUsers = "settings.blocked_users"
        public static let blockUser = "settings.block_user"
        public static let unblock = "settings.unblock"
        public static let blockUserTitle = "settings.block_user_title"
        public static let blockUserWarning = "settings.block_user_warning"
        public static let blockUserDescription = "settings.block_user_description"
        public static let blockReason = "settings.block_reason"
        public static let noBlockedUsers = "settings.no_blocked_users"
        public static let noBlockedUsersDescription = "settings.no_blocked_users_description"
        public static let blockedOn = "settings.blocked_on"
        public static let unblockUser = "settings.unblock_user"
        public static let unblockConfirm = "settings.unblock_confirm"
    }

    // MARK: - Chat
    public enum Chat {
        public static let messages = "Chat.messages"
        public static let newChat = "Chat.newChat"
        public static let noMessages = "Chat.noMessages"
        public static let typeMessage = "Chat.typeMessage"
        public static let sendMessage = "Chat.sendMessage"
        public static let typing = "Chat.typing"
        public static let online = "Chat.online"
        public static let offline = "Chat.offline"
    }

    // MARK: - Forum
    public enum Forum {
        public static let title = "forum.title"
        public static let newPost = "forum.new_post"
        public static let discussion = "forum.discussion"
        public static let comments = "forum.comments"
        public static let trending = "forum.trending"
        public static let noComments = "forum.no_comments"
        public static let postReply = "forum.post_reply"
    }

    // MARK: - Challenges
    public enum Challenges {
        public static let title = "challenge.title"
        public static let leaderboard = "challenge.leaderboard.title"
        public static let shuffle = "challenge.shuffle"
        public static let accept = "ChallengeReveal.accept"
        public static let skip = "ChallengeReveal.skip"
    }

    // MARK: - Map
    public enum Map {
        public static let nearby = "map.nearby"
        public static let location = "map.location"
        public static let distance = "map.distance"
        public static let directions = "map.directions"
        public static let requestItem = "map.request_item"
        public static let itemsNearby = "map.items_nearby"
    }

    // MARK: - Empty States
    public enum EmptyState {
        public static let noResultsTitle = "empty_state.no_results.title"
        public static let noResultsAction = "empty_state.no_results.action"
        public static let noListingsTitle = "empty_state.no_listings.title"
        public static let noListingsMessage = "empty_state.no_listings.message"
        public static let noListingsAction = "empty_state.no_listings.action"
    }

    // MARK: - Errors
    public enum Errors {
        public static let title = "errors.title"
        public static let network = "errors.network"
        public static let unknown = "errors.unknown"
        public static let notFoundTitle = "errors.not_found.title"
        public static let notFoundPost = "errors.not_found.post"
        public static let notFoundListing = "errors.not_found.listing"
    }

    // MARK: - Accessibility
    public enum Accessibility {
        public static let loading = "accessibility.loading"
        public static let loaded = "accessibility.loaded"
        public static let expired = "accessibility.expired"
        public static let trending = "accessibility.trending"
        public static let distanceAway = "accessibility.distance_away"
        public static let verifiedUser = "accessibility.verified_user"
    }

    // MARK: - Biometric
    public enum Biometric {
        public static let locked = "biometric.locked"
        public static let authRequired = "biometric.auth_required"
        public static let verifyIdentity = "biometric.verify_identity"
        public static let usePasscode = "biometric.use_passcode"
        public static let tapToUnlock = "biometric.tap_to_unlock"
    }

    // MARK: - Onboarding
    public enum Onboarding {
        public static let welcome = "onboarding.welcome"
        public static let tagline = "onboarding.tagline"
        public static let featureShare = "onboarding.feature_share"
        public static let featureFind = "onboarding.feature_find"
        public static let featureCommunity = "onboarding.feature_community"
    }

    // MARK: - Help
    public enum Help {
        public static let title = "help.title"
        public static let contactSupport = "help.contact_support"
        public static let sendFeedback = "help.send_feedback"
        public static let popularTopics = "help.popular_topics"
    }

    // MARK: - Reviews
    public enum Reviews {
        public static let title = "reviews.title"
        public static let writeReview = "reviews.write_review"
        public static let submitReview = "reviews.submit_review"
        public static let noReviews = "reviews.no_reviews"
    }

    // MARK: - Arrangement
    public enum Arrangement {
        public static let arrange = "arrangement.request_pickup"
        public static let arranged = "arrangement.status.arranged"
        public static let available = "arrangement.status.available"
        public static let completed = "arrangement.status.completed"
    }

    // MARK: - Community Fridges
    public enum CommunityFridges {
        public static let title = "navigation.community_fridges"
        public static let foodLevel = "fridge.food_level"
        public static let cleanliness = "fridge.cleanliness"
        public static let reportIssue = "fridge.report_issue"
        public static let getDirections = "fridge.get_directions"
    }

    // MARK: - Insights
    public enum Insights {
        public static let title = "insights.title"
        public static let impactScore = "insights.impact_score"
        public static let foodSaved = "insights.food_saved"
        public static let co2Prevented = "insights.co2_prevented"
    }

    // MARK: - Notifications
    public enum Notifications {
        public static let title = "notifications.title"
        public static let empty = "notifications.empty"
        public static let markAllRead = "notifications.mark_all_read"
    }

    // MARK: - Notification Settings (Enterprise)
    public enum NotificationSettings {
        // Section Titles
        public static let title = "settings.notifications.title"
        public static let push = "settings.notifications.push"
        public static let email = "settings.notifications.email"
        public static let sms = "settings.notifications.sms"
        public static let digest = "settings.notifications.digest"
        public static let quietHours = "settings.notifications.quiet_hours"
        public static let dnd = "settings.notifications.dnd"

        // General
        public static let enabled = "settings.notifications.enabled"
        public static let disabled = "settings.notifications.disabled"

        // Categories
        public static let categoryPosts = "settings.notifications.category.posts"
        public static let categoryForum = "settings.notifications.category.forum"
        public static let categoryChallenges = "settings.notifications.category.challenges"
        public static let categoryComments = "settings.notifications.category.comments"
        public static let categoryChats = "settings.notifications.category.chats"
        public static let categorySocial = "settings.notifications.category.social"
        public static let categorySystem = "settings.notifications.category.system"
        public static let categoryMarketing = "settings.notifications.category.marketing"

        // Frequencies
        public static let frequencyInstant = "settings.notifications.frequency.instant"
        public static let frequencyHourly = "settings.notifications.frequency.hourly"
        public static let frequencyDaily = "settings.notifications.frequency.daily"
        public static let frequencyWeekly = "settings.notifications.frequency.weekly"
        public static let frequencyNever = "settings.notifications.frequency.never"

        // Digest
        public static let dailyDigest = "settings.notifications.daily_digest"
        public static let dailyDigestDesc = "settings.notifications.daily_digest_desc"
        public static let weeklyDigest = "settings.notifications.weekly_digest"
        public static let weeklyDigestDesc = "settings.notifications.weekly_digest_desc"

        // Quiet Hours
        public static let quietHoursDesc = "settings.notifications.quiet_hours_desc"
        public static let quietHoursStart = "settings.notifications.quiet_hours_start"
        public static let quietHoursEnd = "settings.notifications.quiet_hours_end"

        // Do Not Disturb
        public static let dndDesc = "settings.notifications.dnd_desc"
        public static let dndActive = "settings.notifications.dnd_active"
        public static let dndTurnOff = "settings.notifications.dnd_turn_off"
        public static let dndFor1Hour = "settings.notifications.dnd_1_hour"
        public static let dndFor2Hours = "settings.notifications.dnd_2_hours"
        public static let dndFor4Hours = "settings.notifications.dnd_4_hours"
        public static let dndFor8Hours = "settings.notifications.dnd_8_hours"
        public static let dndFor24Hours = "settings.notifications.dnd_24_hours"

        // Phone Verification
        public static let verifyPhone = "settings.notifications.verify_phone"
        public static let verifyPhoneDesc = "settings.notifications.verify_phone_desc"
        public static let enterPhoneNumber = "settings.notifications.enter_phone"
        public static let enterVerificationCode = "settings.notifications.enter_code"
        public static let sendCode = "settings.notifications.send_code"
        public static let verifyCode = "settings.notifications.verify_code"
    }
}

// MARK: - Interpolated Keys

/// Keys that require interpolation arguments.
public enum TKInterpolated {
    /// "{count} items nearby" - requires: count
    public struct ItemsNearby: TranslationKeyWithArgs {
        public static let key = "map.items_nearby"
        public static let args = ["count"]
        public init() {}
    }

    /// "{count} views" - requires: count
    public struct ViewsCount: TranslationKeyWithArgs {
        public static let key = "views_count"
        public static let args = ["count"]
        public init() {}
    }

    /// "{count} comments" - requires: count
    public struct CommentsCount: TranslationKeyWithArgs {
        public static let key = "forum.comments_count"
        public static let args = ["count"]
        public init() {}
    }

    /// "{count} reviews" - requires: count
    public struct ReviewsCount: TranslationKeyWithArgs {
        public static let key = "reviews.count"
        public static let args = ["count"]
        public init() {}
    }

    /// "{distance} away" - requires: distance
    public struct DistanceAway: TranslationKeyWithArgs {
        public static let key = "accessibility.distance_away"
        public static let args = ["distance"]
        public init() {}
    }

    /// "Level {level}" - requires: level
    public struct ProfileLevel: TranslationKeyWithArgs {
        public static let key = "profile.level"
        public static let args = ["level"]
        public init() {}
    }
}

// MARK: - Protocol

public protocol TranslationKeyWithArgs {
    static var key: String { get }
    static var args: [String] { get }
}

#endif
