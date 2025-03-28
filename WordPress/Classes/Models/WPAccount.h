#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Blog;
@class ManagedAccountSettings;
@class WordPressComRestApi;

@interface WPAccount : NSManagedObject

///-----------------
/// @name Properties
///-----------------

@property (nonatomic, strong)   NSNumber    *userID;
@property (nonatomic, strong)   NSString    *avatarURL;
@property (nonatomic, copy)     NSString    *username;
@property (nonatomic, copy)     NSString    *uuid;
@property (nonatomic, strong)   NSDate      *dateCreated;
@property (nonatomic, strong)   NSString    *email;
@property (nonatomic, strong)   NSString    *displayName;
@property (nonatomic, strong)   NSNumber    *emailVerified;
@property (nonatomic, strong)   NSNumber    *primaryBlogID;
@property (nonatomic, strong)   NSSet<Blog *>       *blogs;
@property (nonatomic, strong)   Blog        *defaultBlog;
@property (nonatomic, strong)   ManagedAccountSettings *settings;

/**
 The OAuth2 auth token for WordPress.com accounts
 */
@property (nonatomic, copy) NSString *authToken;


///------------------
/// @name API Helpers
///------------------

/// A WordPressRestComApi object if the account is a WordPress.com account. Otherwise, it returns `nil`.
///
/// Important: Do not set this directly!
///
/// It's reserved for Objective-C to Swift interoperability in the context of separating this model from the app target and will be removed at some point.
@property (nonatomic, strong) WordPressComRestApi *_private_wordPressComRestApi;

@end

@interface WPAccount (CoreDataGeneratedAccessors)

- (void)addBlogsObject:(Blog *)value;
- (void)removeBlogsObject:(Blog *)value;
- (void)addBlogs:(NSSet *)values;
- (void)removeBlogs:(NSSet *)values;
+ (NSString *)tokenForUsername:(NSString *)username isJetpack:(BOOL)isJetpack;
- (BOOL)hasAtomicSite;

@end
