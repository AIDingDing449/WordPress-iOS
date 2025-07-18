#import <Foundation/Foundation.h>

@protocol PostContentProvider <NSObject>
- (NSString *)titleForDisplay;
- (NSString *)authorForDisplay;
- (NSString *)contentForDisplay;
- (NSString *)contentPreviewForDisplay;
- (NSURL *)avatarURLForDisplay; // Some providers use a hardcoded URL or blavatar URL
- (NSString *)gravatarEmailForDisplay;
- (NSDate *)dateForDisplay;
@optional
- (NSString *)blogNameForDisplay;
- (NSURL *)featuredImageURLForDisplay;
- (NSURL *)authorURL;
- (NSArray <NSString *> *)tagsForDisplay;
@end
