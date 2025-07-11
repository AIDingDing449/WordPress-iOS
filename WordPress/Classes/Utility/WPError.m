#import "WPError.h"
#import "WordPress-Swift.h"
@import WordPressData;
@import WordPressShared;
@import WordPressKit;


@interface WPError ()

@property (nonatomic, assign) BOOL alertShowing;

@end

@implementation WPError

+ (instancetype)internalInstance
{
    static WPError *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WPError alloc] init];
    });
    return instance;
}

+ (void)showNetworkingAlertWithError:(NSError *)error
{
    [self showNetworkingAlertWithError:error title:nil];
}

+ (void)showNetworkingAlertWithError:(NSError *)error title:(NSString *)title
{
    if ([self showWPComSigninIfErrorIsInvalidAuth:error]) {
        return;
    }
    
    NSDictionary *titleAndMessage = [self titleAndMessageFromNetworkingError:error desiredTitle:title];
    
    [self showAlertWithTitle:titleAndMessage[@"title"]
                     message:titleAndMessage[@"message"]
           withSupportButton:YES
              okPressedBlock:nil];
}


+ (NSDictionary<NSString *,NSString *> *)titleAndMessageFromNetworkingError:(NSError *)error
                                                               desiredTitle:(NSString *)desiredTitle
{
    NSString *message = nil;
    NSString *title = nil;
    
    if (desiredTitle != nil) {
        title = desiredTitle;
    } else if (title == nil) {
        title = NSLocalizedString(@"Error", @"Generic error alert title");
    }
    
    if (message == nil) {
        message = [error localizedDescription];
        message = [NSString decodeXMLCharactersIn:message];
    }
    
    return @{@"title": title, @"message": message};
}

+ (BOOL)showWPComSigninIfErrorIsInvalidAuth:(nonnull NSError *)error {
    if ([error.domain isEqualToString:WordPressComRestApiErrorDomain]) {
        DDLogError(@"wp.com API error: %@: %@", error.userInfo[WordPressComRestApi.ErrorKeyErrorCode],
                   [error localizedDescription]);
        if (error.code == WordPressComRestApiErrorCodeInvalidToken || error.code == WordPressComRestApiErrorCodeAuthorizationRequired) {
            [ObjCBridge showSigninForWPComFixingAuthToken];
            return YES;
        }
    }
    
    return NO;
}

+ (void)showAlertWithTitle:(NSString *)title message:(NSString *)message
{
    [self showAlertWithTitle:title message:message withSupportButton:YES okPressedBlock:nil];
}

+ (void)showAlertWithTitle:(NSString *)title message:(NSString *)message withSupportButton:(BOOL)showSupport
{
    [self showAlertWithTitle:title message:message withSupportButton:showSupport okPressedBlock:nil];
}

+ (void)showAlertWithTitle:(NSString *)title message:(NSString *)message withSupportButton:(BOOL)showSupport okPressedBlock:(void (^)(UIAlertController *))okBlock
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([WPError internalInstance].alertShowing) {
            return;
        }
        [WPError internalInstance].alertShowing = YES;

        DDLogInfo(@"Showing alert with title: %@ and message %@", title, message);
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:[message stringByStrippingHTML]
                                                                          preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *action = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                         style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull __unused action) {
                                                             if (okBlock) {
                                                                 okBlock(alertController);
                                                             }
                                                             [WPError internalInstance].alertShowing = NO;
                                                         }];
        [alertController addAction:action];
        
        // Add the 'Need help' button only if internet is accessible (i.e. if the user can actually get help).
        if (showSupport) {
            NSString *supportText = NSLocalizedString(@"Need Help?", @"'Need help?' button label, links off to the WP for iOS FAQ.");
            UIAlertAction *action = [UIAlertAction actionWithTitle:supportText style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull __unused action) {
                [ObjCBridge showSupportTableViewController];
                [WPError internalInstance].alertShowing = NO;
            }];
            [alertController addAction:action];
        }
        [alertController presentFromRootViewController];
    });
}

@end
