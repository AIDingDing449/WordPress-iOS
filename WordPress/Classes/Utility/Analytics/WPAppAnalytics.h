#import <Foundation/Foundation.h>

@import WordPressSharedObjC;

@class Blog, AbstractPost, AccountService;

extern NSString * const WPAppAnalyticsDefaultsUserOptedOut;
extern NSString * const WPAppAnalyticsDefaultsKeyUsageTracking_deprecated;
extern NSString * const WPAppAnalyticsKeyBlogID;
extern NSString * const WPAppAnalyticsKeyPostID;
extern NSString * const WPAppAnalyticsKeyPostAuthorID;
extern NSString * const WPAppAnalyticsKeyFeedID;
extern NSString * const WPAppAnalyticsKeyFeedItemID;
extern NSString * const WPAppAnalyticsKeyIsJetpack;
extern NSString * const WPAppAnalyticsKeyEditorSource;
extern NSString * const WPAppAnalyticsKeyCommentID;
extern NSString * const WPAppAnalyticsKeyLegacyQuickAction;
extern NSString * const WPAppAnalyticsKeyQuickAction;
extern NSString * const WPAppAnalyticsKeyFollowAction;
extern NSString * const WPAppAnalyticsKeySource;
extern NSString * const WPAppAnalyticsKeyPostType;
extern NSString * const WPAppAnalyticsKeyTapSource;
extern NSString * const WPAppAnalyticsKeyTabSource;
extern NSString * const WPAppAnalyticsKeyReplyingTo;
extern NSString * const WPAppAnalyticsKeySiteType;
extern NSString * const WPAppAnalyticsValueSiteTypeBlog;
extern NSString * const WPAppAnalyticsValueSiteTypeP2;

/**
 *  @class      WPAppAnalytics
 *  @brief      This is a container for the app-specific analytics logic.
 *  @details    WPAnalytics is a generic component.  This component acts as a container for all
 *              of the WPAnalytics code that's specific to WordPress, interfacing with WPAnalytics
 *              where appropiate.  This is mostly useful to remove such app-specific logic from
 *              our app delegate class.
 */
@interface WPAppAnalytics : NSObject

/**
 *  @brief      Timestamp of the app's opening time.
 */
@property (nonatomic, strong, readwrite) NSDate* applicationOpenedTime;

#pragma mark - Init

/**
 *  @brief      Default initializer.
 *
 *  @returns    The initialized object.
 */
- (instancetype)init;

/**
 *  @brief      Returns the site type for the blogID. Default is "blog".
 */
+ (NSString *)siteTypeForBlogWithID:(NSNumber *)blogID;

#pragma mark - User Opt Out

/**
 *  @brief      Call this method to know if the user has opted out of tracking.
 *
 *  @returns    YES if the user has opted out, NO otherwise.
 */
+ (BOOL)userHasOptedOut;

/**
 *  @brief      Sets user opt out ON or OFF
 *
 *  @param      optedOut   The new status for user opt out.
 */
- (void)setUserHasOptedOut:(BOOL)optedOut;

#pragma mark - Usage tracking

/**
 *  @brief      Call this method to know if usage is being tracked.
 *
 *  @returns    YES if usage is being tracked, NO otherwise.
 */
+ (BOOL)isTrackingUsage __attribute__((deprecated("Use userHasOptedOut instead.")));

/**
 *  @brief      Sets usage tracking ON or OFF
 *
 *  @param      trackingUsage   The new status for usage tracking.
 */
- (void)setTrackingUsage:(BOOL)trackingUsage __attribute__((deprecated("Use setUserHasOptedOut instead.")));

/**
 *  @brief      Tracks stats with the blog details when available
 */
+ (void)track:(WPAnalyticsStat)stat withBlog:(Blog *)blog;

/**
 *  @brief      Tracks stats with the blog_id when available
 */
+ (void)track:(WPAnalyticsStat)stat withBlogID:(NSNumber*)blogID;

/**
 *  @brief      Tracks stats with the blog details when available
 */
+ (void)track:(WPAnalyticsStat)stat withProperties:(NSDictionary *)properties withBlog:(Blog *)blog;

/**
 *  @brief      Tracks stats with the blog_id when available
 */
+ (void)track:(WPAnalyticsStat)stat withProperties:(NSDictionary *)properties withBlogID:(NSNumber*)blogID;

/**
 *  @brief      Tracks stats with the post details when available
 */
+ (void)track:(WPAnalyticsStat)stat withPost:(AbstractPost *)postOrPage;

/**
 *  @brief      Tracks stats with the post details when available
 */
+ (void)track:(WPAnalyticsStat)stat withProperties:(NSDictionary *)properties withPost:(AbstractPost *)postOrPage;

/**
    @brief      Used only for bumping the TrainTracks interaction event. The stat's
                event name is passed as an "action" property.
 */
+ (void)trackTrainTracksInteraction:(WPAnalyticsStat)stat withProperties:(NSDictionary *)properties;

/**
 *  @brief      Pass-through methods to WPAnalytics
 */
+ (void)track:(WPAnalyticsStat)stat;

+ (void)track:(WPAnalyticsStat)stat withProperties:(NSDictionary *)properties;

/**
 *  @brief      Track Anaylytics with associate error that is translated to properties
 */
+ (void)track:(WPAnalyticsStat)stat error:(NSError *)error;

/**
 *  @brief      Track Anaylytics with associate error that is translated to properties, along with available blog details
 */
+ (void)track:(WPAnalyticsStat)stat error:(NSError *)error withBlogID:(NSNumber *)blogID;
@end
