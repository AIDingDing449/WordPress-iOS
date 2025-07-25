#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@class WPAccount;
@class RemoteUser;
@protocol CoreDataStack;

extern NSNotificationName const WPAccountEmailAndDefaultBlogUpdatedNotification;

@interface AccountService : NSObject

@property (nonatomic, strong, readonly) id<CoreDataStack> coreDataStack;

- (nonnull instancetype)initWithCoreDataStack:(id<CoreDataStack>)coreDataStack NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

///------------------------------------
/// @name Default WordPress.com account
///------------------------------------

/**
 Query to check if an email address is paired to a wpcom account. Used in the 
 magic links signup flow.

 @param email
 @param success
 @param failure
 */
- (void)isEmailAvailable:(NSString *)email success:(void (^)(BOOL available))success failure:(void (^)(NSError *error))failure;

/**
 Requests a verification email to be sent to the email address associated with the current account.

 @param success
 @param failure
 */
- (void)requestVerificationEmail:(void (^)(void))success
                         failure:(void (^)(NSError *error))failure;



///-----------------------
/// @name Account creation
///-----------------------

/**
 Creates a new WordPress.com account or updates the password if there is a matching account
 
 There can only be one WordPress.com account per username, so if one already exists for the given `username` its password is updated
 
 Uses a background managed object context.
 
 @param username the WordPress.com account's username
 @param authToken the OAuth2 token returned by signIntoWordPressDotComWithUsername:authToken:
 @return The ID of the WordPress.com `WPAccount` object for the given `username`
 */
- (NSManagedObjectID *)createOrUpdateAccountWithUsername:(NSString *)username authToken:(NSString *)authToken;

/**
 Updates user details including username, email, userID, avatarURL, and default blog.

 @param account WPAccount to be updated
 */
- (void)updateUserDetailsForAccount:(WPAccount *)account
                            success:(nullable void (^)(void))success
                            failure:(nullable void (^)(NSError *error))failure;

/**
 Updates the default blog for the specified account.  The default blog will be the one whose siteID matches
 the accounts primaryBlogID.
 */
- (void)updateDefaultBlogIfNeeded:(WPAccount *)account inContext:(NSManagedObjectContext *)context;

/**
 Syncs the details for the account associated with the provided auth token, then
 creates or updates a WPAccount with the synced information.

 @param authToken The auth token associated with the account being created/updated.
 @param success A success block.
 @param failure A failure block.
 */
- (void)createOrUpdateAccountWithAuthToken:(NSString *)authToken
                                   success:(void (^)(WPAccount * _Nonnull))success
                                   failure:(void (^)(NSError * _Nonnull))failure;

- (NSManagedObjectID *)createOrUpdateAccountWithUserDetails:(RemoteUser *)remoteUser authToken:(NSString *)authToken;

/**
 Removes an account if it's not the default account and there are no associated blogs
 */
- (void)purgeAccountIfUnused:(WPAccount *)account;

/**
 Restores a disassociated default WordPress.com account if the current defaultWordPressCom account is nil
 and another candidate account is found.  This method bypasses the normal setter to avoid triggering unintended
 side-effects from dispatching account changed notifications.
 */
- (void)restoreDisassociatedAccountIfNecessary;

@end

NS_ASSUME_NONNULL_END
