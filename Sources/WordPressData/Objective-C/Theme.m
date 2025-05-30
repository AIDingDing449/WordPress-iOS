#import "Theme.h"
#import "Blog.h"
#import "WPAccount.h"

@import WordPressShared;

static NSString* const ThemeAdminUrlCustomize = @"customize.php?theme=%@&hide_close=true";
static NSString* const ThemeUrlDemoParameters = @"?demo=true&iframe=true&theme_preview=true";
static NSString* const ThemeUrlSupport = @"https://wordpress.com/themes/%@/support/?preview=true&iframe=true";
static NSString* const ThemeUrlDetails = @"https://wordpress.com/themes/%@/%@/?preview=true&iframe=true";

@implementation Theme

@dynamic popularityRank;
@dynamic details;
@dynamic themeId;
@dynamic premium;
@dynamic launchDate;
@dynamic screenshotUrl;
@dynamic trendingRank;
@dynamic version;
@dynamic author;
@dynamic authorUrl;
@dynamic tags;
@dynamic name;
@dynamic previewUrl;
@dynamic price;
@dynamic purchased;
@dynamic demoUrl;
@dynamic themeUrl;
@dynamic stylesheet;
@dynamic order;
@dynamic custom;
@dynamic blog;

#pragma mark - CoreData helpers

+ (NSString *)entityName
{
    return NSStringFromClass([self class]);
}

#pragma mark - Links

- (NSString *)detailsUrl
{
    if (self.custom) {
        return self.themeUrl;
    }
    NSString *homeUrl = self.blog.homeURL.hostname;

    return [NSString stringWithFormat:ThemeUrlDetails, homeUrl, self.themeId];
}

- (NSString *)supportUrl
{
    return [NSString stringWithFormat:ThemeUrlSupport, self.themeId];
}

- (NSString *)viewUrl
{
    return [self.demoUrl stringByAppendingString:ThemeUrlDemoParameters];
}

#pragma mark - Misc

- (BOOL)isCurrentTheme
{
    return [self.blog.currentThemeId isEqualToString:self.themeId];
}

- (BOOL)isPremium
{
    return [self.premium boolValue];
}

- (BOOL)hasDetailsURL
{
    return self.detailsUrl.length > 0;
}

@end
