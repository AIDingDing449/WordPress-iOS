#import "WPAppAnalytics.h"

@import WordPressDataObjC;
#import "WPAnalyticsTrackerWPCom.h"
#import "WPAnalyticsTrackerAutomatticTracks.h"
#import "WPTabBarController.h"
#import "AccountService.h"
#import "BlogService.h"
#import "Blog.h"
#import "AbstractPost.h"
#import "WordPress-Swift.h"

@import NSObject_SafeExpectations;

NSString * const WPAppAnalyticsDefaultsUserOptedOut                 = @"tracks_opt_out";
NSString * const WPAppAnalyticsDefaultsKeyUsageTracking_deprecated  = @"usage_tracking_enabled";
NSString * const WPAppAnalyticsKeyBlogID                            = @"blog_id";
NSString * const WPAppAnalyticsKeyPostID                            = @"post_id";
NSString * const WPAppAnalyticsKeyPostAuthorID                      = @"post_author_id";
NSString * const WPAppAnalyticsKeyFeedID                            = @"feed_id";
NSString * const WPAppAnalyticsKeyFeedItemID                        = @"feed_item_id";
NSString * const WPAppAnalyticsKeyIsJetpack                         = @"is_jetpack";
NSString * const WPAppAnalyticsKeySubscriptionCount                 = @"subscription_count";
NSString * const WPAppAnalyticsKeyEditorSource                      = @"editor_source";
NSString * const WPAppAnalyticsKeyCommentID                         = @"comment_id";
NSString * const WPAppAnalyticsKeyLegacyQuickAction                 = @"is_quick_action";
NSString * const WPAppAnalyticsKeyQuickAction                       = @"quick_action";
NSString * const WPAppAnalyticsKeyFollowAction                      = @"follow_action";
NSString * const WPAppAnalyticsKeySource                            = @"source";
NSString * const WPAppAnalyticsKeyPostType                          = @"post_type";
NSString * const WPAppAnalyticsKeyTapSource                         = @"tap_source";
NSString * const WPAppAnalyticsKeyTabSource                         = @"tab_source";
NSString * const WPAppAnalyticsKeyReplyingTo                        = @"replying_to";
NSString * const WPAppAnalyticsKeySiteType                          = @"site_type";

NSString * const WPAppAnalyticsKeyHasGutenbergBlocks                = @"has_gutenberg_blocks";
NSString * const WPAppAnalyticsKeyHasStoriesBlocks                  = @"has_wp_stories_blocks";

NSString * const WPAppAnalyticsValueSiteTypeBlog                    = @"blog";
NSString * const WPAppAnalyticsValueSiteTypeP2                      = @"p2";

@implementation WPAppAnalytics

#pragma mark - Init

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        [self initializeAppTracking];
        [self startObservingNotifications];
    }
    
    return self;
}

#pragma mark - Init helpers

/**
 *  @brief      Initializes analytics tracking for WPiOS.
 */
- (void)initializeAppTracking
{
    [self initializeOptOutTracking];

    BOOL userHasOptedOut = [WPAppAnalytics userHasOptedOut];
    BOOL isUITesting = [[NSProcessInfo processInfo].arguments containsObject:@"-ui-testing"];
    if (!isUITesting && !userHasOptedOut) {
        [self registerTrackers];
        [self beginSession];
    }
}

- (void)registerTrackers
{
    [WPAnalytics registerTracker:[WPAnalyticsTrackerWPCom new]];
    [WPAnalytics registerTracker:[WPAnalyticsTrackerAutomatticTracks new]];
}

- (void)clearTrackers
{
    [WPAnalytics clearQueuedEvents];
    [WPAnalytics clearTrackers];
}

+ (NSString *)siteTypeForBlogWithID:(NSNumber *)blogID
{
    NSManagedObjectContext *context = [[ContextManager sharedInstance] mainContext];
    Blog *blog = [Blog lookupWithID:blogID in:context];
    return [blog isWPForTeams] ? WPAppAnalyticsValueSiteTypeP2 : WPAppAnalyticsValueSiteTypeBlog;
}

#pragma mark - Notifications

- (void)startObservingNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(accountSettingsDidChange:)
                                                 name:NSNotification.AccountSettingsChanged
                                               object:nil];
}

#pragma mark - Notifications

- (void)accountSettingsDidChange:(NSNotification*)notification
{
    NSManagedObjectContext *context = [[ContextManager sharedInstance] mainContext];
    WPAccount *defaultAccount = [WPAccount lookupDefaultWordPressComAccountInContext:context];
    if (!defaultAccount.settings) {
        return;
    }

    [self setUserHasOptedOut:defaultAccount.settings.tracksOptOut];
}

#pragma mark - App Tracking

/**
 *  @brief      Tracks stats with the blog details when available
 */
+ (void)track:(WPAnalyticsStat)stat withBlog:(Blog *)blog {
    [WPAppAnalytics track:stat withBlogID:blog.dotComID];
}

/**
 *  @brief      Tracks stats with the blog_id when available
 */
+ (void)track:(WPAnalyticsStat)stat withBlogID:(NSNumber *)blogID {
    if (NSThread.isMainThread) {
        [WPAppAnalytics track:stat withProperties:nil withBlogID:blogID];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [WPAppAnalytics track:stat withProperties:nil withBlogID:blogID];
        });
    }
}

/**
 *  @brief      Tracks stats with the blog details when available
 */
+ (void)track:(WPAnalyticsStat)stat withProperties:(NSDictionary *)properties withBlog:(Blog *)blog {
    [WPAppAnalytics track:stat withProperties:properties withBlogID:blog.dotComID];
}

/**
 *  @brief      Tracks stats with the blog_id when available
 */
+ (void)track:(WPAnalyticsStat)stat withProperties:(NSDictionary *)properties withBlogID:(NSNumber *)blogID {
    NSMutableDictionary *mutableProperties;
    if (properties) {
        mutableProperties = [NSMutableDictionary dictionaryWithDictionary:properties];
    } else {
        mutableProperties = [NSMutableDictionary new];
    }
    
    if (blogID) {
        [mutableProperties setObject:blogID forKey:WPAppAnalyticsKeyBlogID];

        NSString *siteType = [self siteTypeForBlogWithID:blogID];
        [mutableProperties setObject:siteType forKey:WPAppAnalyticsKeySiteType];
    }
    
    if ([mutableProperties count] > 0) {
        [WPAppAnalytics track:stat withProperties:mutableProperties];
    } else {
        [WPAppAnalytics track:stat];
    }
}

+ (void)track:(WPAnalyticsStat)stat withPost:(AbstractPost *)postOrPage {
    [WPAppAnalytics track:stat withProperties:nil withPost:postOrPage];
}

+ (void)track:(WPAnalyticsStat)stat withProperties:(NSDictionary *)properties withPost:(AbstractPost *)postOrPage {
    NSMutableDictionary *mutableProperties;
    if (properties) {
        mutableProperties = [NSMutableDictionary dictionaryWithDictionary:properties];
    } else {
        mutableProperties = [NSMutableDictionary new];
    }

    if (postOrPage.postID.integerValue > 0) {
        mutableProperties[WPAppAnalyticsKeyPostID] = postOrPage.postID;
    }
    mutableProperties[WPAppAnalyticsKeyHasGutenbergBlocks] = @([postOrPage containsGutenbergBlocks]);
    mutableProperties[WPAppAnalyticsKeyHasStoriesBlocks] = @([postOrPage containsStoriesBlocks]);

    [WPAppAnalytics track:stat withProperties:mutableProperties withBlog:postOrPage.blog];
}


+ (void)trackTrainTracksInteraction:(WPAnalyticsStat)stat withProperties:(NSDictionary *)properties
{
    NSMutableDictionary *mutableProperties;
    if (properties) {
        mutableProperties = [NSMutableDictionary dictionaryWithDictionary:properties];
    } else {
        mutableProperties = [NSMutableDictionary new];
    }
    // TrainTracks are specific to the AutomatticTracks tracker.
    // The action property should be the event string for the stat.
    // Other trackers should ignore `WPAnalyticsStatTrainTracksInteract`
    NSString *eventName = [WPAnalyticsTrackerAutomatticTracks eventNameForStat:stat];
    [mutableProperties setObject:eventName forKey:@"action"];

    [self track:WPAnalyticsStatTrainTracksInteract withProperties:mutableProperties];
}

/**
 *  @brief      Pass-through method to [WPAnalytics track:stat]. Use this method instead of calling WPAnalytics directly.
 */
+ (void)track:(WPAnalyticsStat)stat {
    [WPAnalytics track:stat];
}

/**
 *  @brief      Pass-through method to WPAnalytics. Use this method instead of calling WPAnalytics directly.
 */
+ (void)track:(WPAnalyticsStat)stat withProperties:(NSDictionary *)properties {
    [WPAnalytics track:stat withProperties:properties];
}

+ (void)track:(WPAnalyticsStat)stat error:(NSError * _Nonnull)error withBlogID:(NSNumber *)blogID {
    NSError *err = [self sanitizedErrorFromError:error];
    NSDictionary *properties = @{
                                 @"error_code": [@(err.code) stringValue],
                                 @"error_domain": err.domain,
                                 @"error_description": err.description
    };
    [self track:stat withProperties: properties withBlogID:blogID];
}

+ (void)track:(WPAnalyticsStat)stat error:(NSError * _Nonnull)error {
    [self track:stat error:error withBlogID:nil];
}

/**
 * @brief   Sanitize an NSError so we're not tracking unnecessary or usless information.
 */
+ (NSError * _Nonnull)sanitizedErrorFromError:(NSError * _Nonnull)error
{
    // WordPressOrgXMLRPCApi will, in certain circumstances, store an entire HTTP response in this key.
    // The information is generally unhelpful.
    // We'll truncate the string to avoid tracking garbage but still allow for some context.
    NSString *dataString = [[error userInfo] stringForKey:WordPressOrgXMLRPCApi.WordPressOrgXMLRPCApiErrorKeyDataString];
    NSUInteger threshold = 100;
    if ([dataString length] > threshold) {
        NSMutableDictionary *dict = [[error userInfo] mutableCopy];
        [dict setObject:[dataString substringToIndex:threshold] forKey:WordPressOrgXMLRPCApi.WordPressOrgXMLRPCApiErrorKeyDataString];
        return [[NSError alloc] initWithDomain:error.domain code:error.code userInfo:dict];
    }
    return error;
}

#pragma mark - Usage tracking

+ (BOOL)isTrackingUsage
{
    return [[UserPersistentStoreFactory userDefaultsInstance] boolForKey:WPAppAnalyticsDefaultsKeyUsageTracking_deprecated];
}

- (void)setTrackingUsage:(BOOL)trackingUsage
{
    if (trackingUsage != [WPAppAnalytics isTrackingUsage]) {
        [[UserPersistentStoreFactory userDefaultsInstance] setBool:trackingUsage
                                                forKey:WPAppAnalyticsDefaultsKeyUsageTracking_deprecated];
    }
}

#pragma mark - Tracks Opt Out

- (void)initializeOptOutTracking {
    if ([WPAppAnalytics userHasOptedOutIsSet]) {
        // We've already configured the opt out setting
        return;
    }

    if ([[UserPersistentStoreFactory userDefaultsInstance] objectForKey:WPAppAnalyticsDefaultsKeyUsageTracking_deprecated] == nil) {
        [self setUserHasOptedOutValue:NO];
    } else if ([[UserPersistentStoreFactory userDefaultsInstance] boolForKey:WPAppAnalyticsDefaultsKeyUsageTracking_deprecated] == NO) {
        // If the user has already explicitly disabled tracking,
        // then we should mirror that to the new setting
        [self setUserHasOptedOutValue:YES];
    } else {
        [self setUserHasOptedOutValue:NO];
    }
}

+ (BOOL)userHasOptedOutIsSet {
    return [[UserPersistentStoreFactory userDefaultsInstance] objectForKey:WPAppAnalyticsDefaultsUserOptedOut] != nil;
}

+ (BOOL)userHasOptedOut {
    return [[UserPersistentStoreFactory userDefaultsInstance] boolForKey:WPAppAnalyticsDefaultsUserOptedOut];
}

/// This method just sets the user defaults value for UserOptedOut, and doesn't
/// do any additional configuration of sessions or trackers.
- (void)setUserHasOptedOutValue:(BOOL)optedOut
{
    [[UserPersistentStoreFactory userDefaultsInstance] setBool:optedOut forKey:WPAppAnalyticsDefaultsUserOptedOut];
}

- (void)setUserHasOptedOut:(BOOL)optedOut
{
    if ([WPAppAnalytics userHasOptedOutIsSet]) {
        BOOL currentValue = [WPAppAnalytics userHasOptedOut];
        if (currentValue == optedOut) {
            return;
        }
    }

    [self setUserHasOptedOutValue:optedOut];

    if (optedOut) {
        [self endSession];
        [self clearTrackers];
    } else {
        [self registerTrackers];
        [self beginSession];
    }
}

#pragma mark - Session

- (void)beginSession
{
    DDLogInfo(@"WPAnalytics session started");
    
    [WPAnalytics beginSession];
}

- (void)endSession
{
    DDLogInfo(@"WPAnalytics session stopped");
    
    [WPAnalytics endSession];
}

@end
