#import "SiteSettingsViewController.h"

#import "BlogService.h"
#import "PostCategoryService.h"
#import "SettingsSelectionViewController.h"
#import "SettingsMultiTextViewController.h"
#import "SettingTableViewCell.h"
#import "SettingsTextViewController.h"
#import "WordPress-Swift.h"
#import "AccountService.h"
@import WordPressData;
@import WordPressKit;
@import WordPressShared;
@import NSURL_IDN;

NS_ENUM(NSInteger, SiteSettingsAccount) {
    SiteSettingsAccountUsername = 0,
    // TODO: Hide this row when authenticating using application password.
    SiteSettingsAccountPassword,
    SiteSettingsAccountCount,
};

NS_ENUM(NSInteger, SiteSettingsHomepage) {
    SiteSettingsHomepageSettings = 0,
    SiteSettingsHomepageCount,
};

NS_ENUM(NSInteger, SiteSettingsEditor) {
    SiteSettingsEditorSelector = 0,
    SiteSettingsEditorCount,
};

NS_ENUM(NSInteger, SiteSettingsWriting) {
    SiteSettingsWritingDefaultCategory = 0,
    SiteSettingsWritingTags,
    SiteSettingsWritingDefaultPostFormat,
    SiteSettingsWritingRelatedPosts,
    SiteSettingsWritingDateAndTimeFormat,
    SiteSettingsPostPerPage,
    SiteSettingsSpeedUpYourSite,
};

NS_ENUM(NSInteger, SiteSettingsAdvanced) {
    SiteSettingsAdvancedStartOver = 0,
    SiteSettingsAdvancedExportContent,
    SiteSettingsAdvancedDeleteSite,
    SiteSettingsAdvancedCount,
};

NS_ENUM(NSInteger, SiteSettingsJetpack) {
    SiteSettingsJetpackSecurity = 0,
    SiteSettingsJetpackConnection,
    SiteSettingsJetpackCount,
};

@interface SiteSettingsViewController () <UITableViewDelegate, UITextFieldDelegate, JetpackConnectionDelegate, PostCategoriesViewControllerDelegate>

#pragma mark - Account Section
@property (nonatomic, strong) SettingTableViewCell *usernameTextCell;
@property (nonatomic, strong) SettingTableViewCell *passwordTextCell;
#pragma mark - Writing Section
@property (nonatomic, strong) SwitchTableViewCell  *editorSelectorCell;
@property (nonatomic, strong) SettingTableViewCell *defaultCategoryCell;
@property (nonatomic, strong) SettingTableViewCell *tagsCell;
@property (nonatomic, strong) SettingTableViewCell *defaultPostFormatCell;
@property (nonatomic, strong) SettingTableViewCell *relatedPostsCell;
@property (nonatomic, strong) SettingTableViewCell *dateAndTimeFormatCell;
@property (nonatomic, strong) SettingTableViewCell *postsPerPageCell;
@property (nonatomic, strong) SettingTableViewCell *speedUpYourSiteCell;
#pragma mark - Media Section
@property (nonatomic, strong) MediaQuotaCell *mediaQuotaCell;
#pragma mark - Discussion Section
@property (nonatomic, strong) SettingTableViewCell *discussionSettingsCell;
#pragma mark - Traffic Section
@property (nonatomic, strong) SwitchTableViewCell *ampSettingCell;
#pragma mark - Jetpack Settings Section
@property (nonatomic, strong) SettingTableViewCell *jetpackSecurityCell;
@property (nonatomic, strong) SettingTableViewCell *jetpackConnectionCell;
#pragma mark - Device Section
@property (nonatomic, strong) SwitchTableViewCell *geotaggingCell;
#pragma mark - Advanced Section
@property (nonatomic, strong) SettingTableViewCell *startOverCell;
@property (nonatomic, strong) WPTableViewCell *exportContentCell;
@property (nonatomic, strong) WPTableViewCell *deleteSiteCell;

@property (nonatomic, strong) Blog *blog;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;

@property (nonatomic, strong) NSArray<NSNumber *> *tableSections;
@property (nonatomic, strong) NSArray<NSNumber *> *writingSectionRows;
@end

@implementation SiteSettingsViewController

- (instancetype)initWithBlog:(Blog *)blog
{
    NSParameterAssert([blog isKindOfClass:[Blog class]]);

    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _blog = blog;
        _username = blog.usernameForSite;
        _password = blog.password;
        [WPStyleGuide configureAutomaticHeightRowsFor:self.tableView];
    }
    return self;
}

- (void)viewDidLoad
{
    DDLogInfo(@"SiteSettingsViewController viewDidLoad");
    [super viewDidLoad];

    self.tableView.cellLayoutMarginsFollowReadableWidth = YES;
    [self.tableView registerClass:[SettingTableViewCell class] forCellReuseIdentifier:SettingsTableViewCellReuseIdentifier];
    [self.tableView registerNib:MediaQuotaCell.nib forCellReuseIdentifier:MediaQuotaCell.defaultReuseIdentifier];

    self.navigationItem.title = NSLocalizedString(@"Settings", @"Title for screen that allows configuration of your blog/site settings.");

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDataModelChange:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:self.blog.managedObjectContext];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAccountChange:)
                                                 name:NSNotification.wpAccountDefaultWordPressComAccountChangedNotificationName
                                               object:nil];

    [WPStyleGuide configureColorsForView:self.view andTableView:self.tableView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshTriggered:) forControlEvents:UIControlEventValueChanged];

    if (self.presentingViewController) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismiss)];
    }

    [self refreshData];

    self.tableView.accessibilityIdentifier = @"siteSettingsTable";
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self.tableView reloadData];
}

- (NSArray *)tableSections
{
    if (_tableSections) {
        return _tableSections;
    }

    NSMutableArray *sections = [NSMutableArray arrayWithObjects:@(SiteSettingsSectionGeneral), nil];

    if (self.bloggingSettingsRowCount > 0) {
        [sections addObject:@(SiteSettingsSectionBlogging)];
    }

    if ([self.blog supports:BlogFeatureHomepageSettings]) {
        [sections addObject:@(SiteSettingsSectionHomepage)];
    }

    if (!self.blog.account) {
        [sections addObject:@(SiteSettingsSectionAccount)];
    }

    // Only add the editor section if the site is not a Simple WP.com site
    if (![GutenbergSettings isSimpleWPComSite:self.blog]) {
        [sections addObject:@(SiteSettingsSectionEditor)];
    }

    if ([self.blog supports:BlogFeatureWPComRESTAPI] && self.blog.isAdmin) {
        [sections addObject:@(SiteSettingsSectionWriting)];
        [sections addObject:@(SiteSettingsSectionDiscussion)];
        if (self.blog.isQuotaAvailable) {
            [sections addObject:@(SiteSettingsSectionMedia)];
        }
        if (self.blog.isHostedAtWPcom && self.blog.settings.ampSupported) {
            [sections addObject:@(SiteSettingsSectionTraffic)];
        }
        if ([self.blog supports:BlogFeatureJetpackSettings]) {
            [sections addObject:@(SiteSettingsSectionJetpackSettings)];
        }
    }

    if ([self.blog supports:BlogFeatureSiteManagement]) {
        [sections addObject:@(SiteSettingsSectionAdvanced)];
    }

    _tableSections = sections;
    return sections;
}

- (NSArray *)writingSectionRows
{
    if (_writingSectionRows) {
        return _writingSectionRows;
    }

    NSMutableArray *rows = [NSMutableArray arrayWithObjects:
                            @(SiteSettingsWritingDefaultCategory),
                            @(SiteSettingsWritingTags),
                            @(SiteSettingsWritingDefaultPostFormat), nil];

    BOOL jetpackFeaturesEnabled = [JetpackFeaturesRemovalCoordinator jetpackFeaturesEnabled];

    if (jetpackFeaturesEnabled) {
        [rows addObject:@(SiteSettingsWritingRelatedPosts)];
    }

    [rows addObject:@(SiteSettingsWritingDateAndTimeFormat)];
    [rows addObject:@(SiteSettingsPostPerPage)];

    if (jetpackFeaturesEnabled && [self.blog supports:BlogFeatureJetpackImageSettings]) {
        [rows addObject:@(SiteSettingsSpeedUpYourSite)];
    }

    _writingSectionRows = rows;
    return rows;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.tableSections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger settingsSection = [self.tableSections[section] integerValue];
    switch (settingsSection) {
        case SiteSettingsSectionGeneral:
        {
            return self.generalSettingsRowCount;
        }
        case SiteSettingsSectionBlogging:
            return self.bloggingSettingsRowCount;
        case SiteSettingsSectionHomepage:
        {
            return SiteSettingsHomepageCount;
        }
        case SiteSettingsSectionAccount:
        {
            return SiteSettingsAccountCount;
        }
        case SiteSettingsSectionEditor:
        {
            return SiteSettingsEditorCount;
        }
        case SiteSettingsSectionWriting:
        {
            return self.writingSectionRows.count;
        }
        case SiteSettingsSectionMedia:
        {
            return 1;
        }
        case SiteSettingsSectionDiscussion:
        {
            return 1;
        }
        case SiteSettingsSectionTraffic:
        {
            return 1;
        }
        case SiteSettingsSectionJetpackSettings:
        {
            if ([Feature enabled:FeatureFlagJetpackDisconnect]) {
                return SiteSettingsJetpackCount;
            }
            return 1;
        }
        case SiteSettingsSectionAdvanced:
        {
            return SiteSettingsAdvancedCount;
        }
    }

    return 0;
}

- (SettingTableViewCell *)usernameTextCell
{
    if (_usernameTextCell){
        return _usernameTextCell;
    }
    _usernameTextCell = [[SettingTableViewCell alloc] initWithLabel:NSLocalizedString(@"Username", @"Label for entering username in the username field")
                                                           editable:NO
                                                    reuseIdentifier:nil];
    return _usernameTextCell;
}

- (SettingTableViewCell *)passwordTextCell
{
    if (_passwordTextCell) {
        return _passwordTextCell;
    }
    _passwordTextCell = [[SettingTableViewCell alloc] initWithLabel:NSLocalizedString(@"Password", @"Label for entering password in password field")
                                                           editable:YES
                                                    reuseIdentifier:nil];
    return _passwordTextCell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForAccountSettingsInRow:(NSInteger)row
{
    switch (row) {
        case SiteSettingsAccountUsername:
            if (self.blog.usernameForSite) {
                [self.usernameTextCell setTextValue:self.blog.usernameForSite];
            } else {
                [self.usernameTextCell setTextValue:NSLocalizedString(@"Enter username", @"(placeholder) Help enter WordPress username")];
            }
            return self.usernameTextCell;

        case SiteSettingsAccountPassword:
            if (self.blog.password) {
                [self.passwordTextCell setTextValue:@"••••••••"];
            } else {
                [self.passwordTextCell setTextValue:NSLocalizedString(@"Enter password", @"(placeholder) Help enter WordPress password")];
            }
            return self.passwordTextCell;

    }
    return nil;
}

- (SwitchTableViewCell *)editorSelectorCell
{
    if (!_editorSelectorCell) {
        _editorSelectorCell = [SwitchTableViewCell new];
        _editorSelectorCell.name = NSLocalizedString(@"Use block editor", @"Option to enable the block editor for new posts");
        _editorSelectorCell.flipSwitch.accessibilityIdentifier = @"useBlockEditorSwitch";
        __weak Blog *blog = self.blog;
        _editorSelectorCell.onChange = ^(BOOL value){
            [GutenbergSettings setGutenbergEnabled:value forBlog:blog];
            [GutenbergSettings postSettingsToRemoteForBlog:blog];
        };
    }
    return _editorSelectorCell;
}

- (SettingTableViewCell *)defaultCategoryCell
{
    if (_defaultCategoryCell){
        return _defaultCategoryCell;
    }
    _defaultCategoryCell = [[SettingTableViewCell alloc] initWithLabel:NSLocalizedString(@"Default Category", @"Label for selecting the default category of a post")
                                                              editable:YES
                                                       reuseIdentifier:nil];
    return _defaultCategoryCell;
}

- (SettingTableViewCell *)tagsCell
{
    if (_tagsCell){
        return _tagsCell;
    }
    _tagsCell = [[SettingTableViewCell alloc] initWithLabel:NSLocalizedString(@"Tags", @"Label for selecting the blogs tags")
                                                              editable: self.blog.isAdmin
                                                       reuseIdentifier:nil];
    return _tagsCell;
}

- (SettingTableViewCell *)defaultPostFormatCell
{
    if (_defaultPostFormatCell){
        return _defaultPostFormatCell;
    }
    _defaultPostFormatCell = [[SettingTableViewCell alloc] initWithLabel:NSLocalizedString(@"Default Post Format", @"Label for selecting the default post format")
                                                                editable:YES
                                                         reuseIdentifier:nil];
    return _defaultPostFormatCell;
}

- (SettingTableViewCell *)relatedPostsCell
{
    if (_relatedPostsCell){
        return _relatedPostsCell;
    }
    _relatedPostsCell = [[SettingTableViewCell alloc] initWithLabel:NSLocalizedString(@"Related Posts", @"Label for selecting the related posts options")
                                                           editable:YES
                                                    reuseIdentifier:nil];
    return _relatedPostsCell;
}

- (SettingTableViewCell *)dateAndTimeFormatCell
{
    if (_dateAndTimeFormatCell) {
        return _dateAndTimeFormatCell;
    }
    _dateAndTimeFormatCell = [[SettingTableViewCell alloc] initWithLabel:NSLocalizedString(@"Date and Time Format", @"Label for selecting the date and time settings section")
                                                                editable:YES
                                                         reuseIdentifier:nil];
    return _dateAndTimeFormatCell;
}

- (SettingTableViewCell *)postsPerPageCell
{
    if (_postsPerPageCell) {
        return _postsPerPageCell;
    }
    _postsPerPageCell = [[SettingTableViewCell alloc] initWithLabel:NSLocalizedString(@"Posts per page", @"Label for selecting the number of posts per page")
                                                           editable:YES
                                                    reuseIdentifier:nil];
    return _postsPerPageCell;
}

- (SettingTableViewCell *)speedUpYourSiteCell
{
    if (_speedUpYourSiteCell) {
        return _speedUpYourSiteCell;
    }

    _speedUpYourSiteCell = [[SettingTableViewCell alloc] initWithLabel:NSLocalizedString(@"Speed up your site", @"Label for selecting the Speed up your site Settings section")
                                                              editable:YES
                                                       reuseIdentifier:nil];
    return _speedUpYourSiteCell;
}

- (MediaQuotaCell *)mediaQuotaCell
{
    if (_mediaQuotaCell){
        return _mediaQuotaCell;
    }
    _mediaQuotaCell = (MediaQuotaCell *)[self.tableView dequeueReusableCellWithIdentifier:MediaQuotaCell.defaultReuseIdentifier];

    _mediaQuotaCell.title = NSLocalizedString(@"Space used", @"Label for showing the available disk space quota available for media");
    _mediaQuotaCell.selectionStyle = UITableViewCellSelectionStyleNone;

    return _mediaQuotaCell;
}


- (SettingTableViewCell *)discussionSettingsCell
{
    if (_discussionSettingsCell) {
        return _discussionSettingsCell;
    }

    _discussionSettingsCell = [[SettingTableViewCell alloc] initWithLabel:NSLocalizedString(@"Discussion", @"Label for selecting the Blog Discussion Settings section")
                                                                 editable:YES
                                                          reuseIdentifier:nil];
    return _discussionSettingsCell;
}

- (SwitchTableViewCell *)ampSettingCell
{
    if (_ampSettingCell) {
        return _ampSettingCell;
    }

    _ampSettingCell = [SwitchTableViewCell new];
    _ampSettingCell.name = NSLocalizedString(@"Accelerated Mobile Pages (AMP)", @"Label for selecting the Accelerated Mobile Pages (AMP) Blog Traffic Setting");
    _ampSettingCell.on = self.blog.settings.ampEnabled;
    __weak __typeof__(self) weakSelf = self;
    _ampSettingCell.onChange = ^(BOOL value){
        weakSelf.blog.settings.ampEnabled = value;
        [weakSelf saveSettings];
        [WPAnalytics trackSettingsChange:@"site_settings" fieldName:@"amp_enabled" value:@(value)];
    };

    return _ampSettingCell;
}

- (SettingTableViewCell *)jetpackSecurityCell
{
    if (_jetpackSecurityCell) {
        return _jetpackSecurityCell;
    }
    _jetpackSecurityCell = [[SettingTableViewCell alloc] initWithLabel:NSLocalizedString(@"Security", @"Label for selecting the Blog Jetpack Security Settings section")
                                                                 editable:YES
                                                          reuseIdentifier:nil];
    return _jetpackSecurityCell;
}

- (SettingTableViewCell *)jetpackConnectionCell
{
    if (_jetpackConnectionCell) {
        return _jetpackConnectionCell;
    }
    _jetpackConnectionCell = [[SettingTableViewCell alloc] initWithLabel:NSLocalizedString(@"Manage Connection", @"Label for managing the Blog Jetpack Connection section")
                                                                editable:YES
                                                         reuseIdentifier:nil];
    return _jetpackConnectionCell;
}

- (void)configureEditorSelectorCell
{
    [self.editorSelectorCell setOn:self.blog.isGutenbergEnabled];
}

- (void)configureDefaultCategoryCell
{
    PostCategory *postCategory = [PostCategory lookupWithBlogObjectID:self.blog.objectID
                                                           categoryID:self.blog.settings.defaultCategoryID
                                                            inContext:[[ContextManager sharedInstance] mainContext]];
    [self.defaultCategoryCell setTextValue:[postCategory categoryName]];
}

- (void)configureDefaultPostFormatCell
{
    [self.defaultPostFormatCell setTextValue:self.blog.defaultPostFormatText];
}

- (void)configurePostsPerPageCell
{
    [self.postsPerPageCell setTextValue:self.blog.settings.postsPerPage.stringValue];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForEditorSettingsAtRow:(NSInteger)row
{
    switch (row) {
        case (SiteSettingsEditorSelector):
            [self configureEditorSelectorCell];
            return self.editorSelectorCell;
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForWritingSettingsAtRow:(NSInteger)row
{
    NSInteger writingRow = [self.writingSectionRows[row] integerValue];
    switch (writingRow) {
        case (SiteSettingsWritingDefaultCategory):
            [self configureDefaultCategoryCell];
            return self.defaultCategoryCell;

        case (SiteSettingsWritingTags):
            return self.tagsCell;

        case (SiteSettingsWritingDefaultPostFormat):
            [self configureDefaultPostFormatCell];
            return self.defaultPostFormatCell;

        case (SiteSettingsWritingRelatedPosts):
            return self.relatedPostsCell;

        case (SiteSettingsWritingDateAndTimeFormat):
            return self.dateAndTimeFormatCell;

        case (SiteSettingsPostPerPage):
            [self configurePostsPerPageCell];
            return self.postsPerPageCell;

        case (SiteSettingsSpeedUpYourSite):
            return self.speedUpYourSiteCell;

    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForMediaSettingsAtRow:(NSInteger)row
{
    if (self.blog.isQuotaAvailable) {
        NSString *formatString = NSLocalizedString(@"%@ of %@ on your site", @"Amount of disk quota being used. First argument is the total percentage being used second argument is total quota allowed in GB.Ex: 33% of 14 GB on your site.");
        self.mediaQuotaCell.value = [[NSString alloc] initWithFormat:formatString, self.blog.quotaPercentageUsedDescription, self.blog.quotaSpaceAllowedDescription];
        self.mediaQuotaCell.percentage = self.blog.quotaPercentageUsed;
    }

    return self.mediaQuotaCell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForJetpackSettingsAtRow:(NSInteger)row
{
    switch (row) {
        case (SiteSettingsJetpackSecurity):
            return self.jetpackSecurityCell;

        case (SiteSettingsJetpackConnection):
            return self.jetpackConnectionCell;
    }
    return nil;
}

- (SettingTableViewCell *)startOverCell
{
    if (_startOverCell) {
        return _startOverCell;
    }

    _startOverCell = [[SettingTableViewCell alloc] initWithLabel:NSLocalizedString(@"Start Over", @"Label for selecting the Start Over Settings item")
                                                        editable:YES
                                                 reuseIdentifier:nil];
    return _startOverCell;
}

- (WPTableViewCell *)exportContentCell
{
    if (_exportContentCell) {
        return _exportContentCell;
    }

    _exportContentCell = [[WPTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    [WPStyleGuide configureTableViewActionCell:_exportContentCell];
    _exportContentCell.textLabel.text = NSLocalizedString(@"Export Content", @"Label for selecting the Export Content Settings item");

    return _exportContentCell;
}

- (WPTableViewCell *)deleteSiteCell
{
    if (_deleteSiteCell) {
        return _deleteSiteCell;
    }

    _deleteSiteCell = [[WPTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    [WPStyleGuide configureTableViewActionCell:_deleteSiteCell];
    _deleteSiteCell.textLabel.text = NSLocalizedString(@"Delete Site", @"Label for selecting the Delete Site Settings item");

    return _deleteSiteCell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForAdvancedSettingsAtRow:(NSInteger)row
{
    switch (row) {
        case SiteSettingsAdvancedStartOver:
            return self.startOverCell;

        case SiteSettingsAdvancedExportContent:
            return self.exportContentCell;

        case SiteSettingsAdvancedDeleteSite:
            return self.deleteSiteCell;
    }

    NSAssert(false, @"Missing Advanced section cell");
    return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"NoCell"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger settingsSection = [self.tableSections[indexPath.section] integerValue];
    switch (settingsSection) {
        case SiteSettingsSectionGeneral:
            return [self tableView:tableView cellForGeneralSettingsInRow:indexPath.row];

        case SiteSettingsSectionBlogging:
            return [self tableView:tableView cellForBloggingSettingsInRow:indexPath.row];

        case SiteSettingsSectionHomepage:
            return self.homepageSettingsCell;

        case SiteSettingsSectionAccount:
            return [self tableView:tableView cellForAccountSettingsInRow:indexPath.row];

        case SiteSettingsSectionEditor:
            return [self tableView:tableView cellForEditorSettingsAtRow:indexPath.row];

        case SiteSettingsSectionWriting:
            return [self tableView:tableView cellForWritingSettingsAtRow:indexPath.row];

        case SiteSettingsSectionMedia:
            return [self tableView:tableView cellForMediaSettingsAtRow:indexPath.row];

        case SiteSettingsSectionDiscussion:
            return self.discussionSettingsCell;

        case SiteSettingsSectionTraffic:
            return self.ampSettingCell;

        case SiteSettingsSectionJetpackSettings:
            return [self tableView:tableView cellForJetpackSettingsAtRow:indexPath.row];

        case SiteSettingsSectionAdvanced:
            return [self tableView:tableView cellForAdvancedSettingsAtRow:indexPath.row];
    }

    NSAssert(false, @"Missing section handler");
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger settingsSection = [self.tableSections[indexPath.section] integerValue];
    switch (settingsSection) {
        case SiteSettingsSectionMedia:
            return MediaQuotaCell.height;
        default:
            return UITableViewAutomaticDimension;
    }
}

#pragma mark - UITableViewDelegate

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSInteger settingsSection = [self.tableSections[section] integerValue];
    return [self titleForHeaderInSection:settingsSection];
}

- (NSString *)titleForHeaderInSection:(NSInteger)section
{
    NSString *headingTitle = nil;
    switch (section) {
        case SiteSettingsSectionGeneral:
            headingTitle = NSLocalizedString(@"General", @"Title for the general section in site settings screen");
            break;

        case SiteSettingsSectionBlogging:
            headingTitle = NSLocalizedString(@"Blogging", @"Title for the blogging section in site settings screen");
            break;

        case SiteSettingsSectionHomepage:
            headingTitle = NSLocalizedString(@"Homepage", @"Title for the homepage section in site settings screen");
            break;

        case SiteSettingsSectionAccount:
            headingTitle = NSLocalizedString(@"Account", @"Title for the account section in site settings screen");
            break;

        case SiteSettingsSectionEditor:
            headingTitle = NSLocalizedString(@"Editor", @"Title for the editor settings section");
            break;

        case SiteSettingsSectionWriting:
            headingTitle = NSLocalizedString(@"Writing", @"Title for the writing section in site settings screen");
            break;

        case SiteSettingsSectionTraffic:
            headingTitle = NSLocalizedString(@"Traffic", @"Title for the traffic section in site settings screen");
            break;

        case SiteSettingsSectionJetpackSettings:
            headingTitle = NSLocalizedString(@"Jetpack", @"Title for the Jetpack section in site settings screen");
            break;

        case SiteSettingsSectionAdvanced:
            headingTitle = NSLocalizedString(@"Advanced", @"Title for the advanced section in site settings screen");
            break;

        case SiteSettingsSectionMedia:
            headingTitle = NSLocalizedString(@"Media", @"Title for the media section in site settings screen");
            break;
    }
    return headingTitle;
}

-(UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    NSInteger settingsSection = [self.tableSections[section] integerValue];
    UIView *footerView = nil;
    switch (settingsSection) {
        case SiteSettingsSectionEditor:
            footerView = [self getEditorSettingsSectionFooterView];
            break;

        case SiteSettingsSectionTraffic:
            footerView = [self getTrafficSettingsSectionFooterView];
            break;
    }
    return footerView;
}

- (void)showLanguageSelectorForBlog:(Blog *)blog
{
    NSParameterAssert(blog);

    __weak __typeof__(self) weakSelf = self;

    LanguageViewController *languageViewController = [[LanguageViewController alloc] initWithBlog:blog];
    languageViewController.onChange = ^(NSNumber *newLanguageID){
        weakSelf.blog.settings.languageID = newLanguageID;
        [weakSelf saveSettings];
        [WPAnalytics trackSettingsChange:@"site_settings" fieldName:@"language" value:newLanguageID];
    };

    [self.navigationController pushViewController:languageViewController animated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectInAccountSectionRow:(NSInteger)row
{
    if (row != SiteSettingsAccountPassword) {
        return;
    }
    SettingsTextViewController *siteTitleViewController = [[SettingsTextViewController alloc] initWithText:self.blog.password
                                                                                               placeholder:NSLocalizedString(@"Enter password", @"(placeholder) Help enter WordPress password")
                                                                                                      hint:@""];
    siteTitleViewController.title = NSLocalizedString(@"Password", @"Title for screen that shows self hosted password editor.");
    siteTitleViewController.mode = SettingsTextModesPassword;
    siteTitleViewController.onValueChanged = ^(id value) {
        if (![value isEqualToString:self.blog.password]) {
            self.password = value;
            [self validateLoginCredentials];
        }
    };
    [self.navigationController pushViewController:siteTitleViewController animated:YES];
}

- (void)showDefaultCategorySelector
{
    NSNumber *defaultCategoryID = self.blog.settings.defaultCategoryID ?: @(PostCategoryUncategorized);
    PostCategory *postCategory = [PostCategory lookupWithBlogObjectID:self.blog.objectID
                                                           categoryID:defaultCategoryID
                                                            inContext:[[ContextManager sharedInstance] mainContext]];
    NSArray *currentSelection = @[];
    if (postCategory){
        currentSelection = @[postCategory];
    }
    PostCategoriesViewController *postCategoriesViewController = [[PostCategoriesViewController alloc] initWithBlog:self.blog
                                                                                                   currentSelection:currentSelection
                                                                                                      selectionMode:CategoriesSelectionModeBlogDefault];
    postCategoriesViewController.delegate = self;
    [self.navigationController pushViewController:postCategoriesViewController animated:YES];
}

- (void)showPostFormatSelector
{
    NSArray *titles = self.blog.sortedPostFormatNames;
    NSArray *formats = self.blog.sortedPostFormats;
    if (titles.count == 0 || self.blog.defaultPostFormatText == nil) {
        return;
    }
    NSString *currentDefaultPostFormat = self.blog.settings.defaultPostFormat;
    if (!currentDefaultPostFormat) {
        currentDefaultPostFormat = formats[0];
    }
    NSDictionary *postFormatsDict = @{
                                      SettingsSelectionDefaultValueKey   : [formats firstObject],
                                      SettingsSelectionTitleKey          : NSLocalizedString(@"Default Post Format", @"Title for screen to select a default post format for a blog"),
                                      SettingsSelectionTitlesKey         : titles,
                                      SettingsSelectionValuesKey         : formats,
                                      SettingsSelectionCurrentValueKey   : currentDefaultPostFormat
                                      };

    SettingsSelectionViewController *vc = [[SettingsSelectionViewController alloc] initWithDictionary:postFormatsDict];
    __weak __typeof__(self) weakSelf = self;
    vc.onItemSelected = ^(NSString *status) {
        // Check if the object passed is indeed an NSString, otherwise we don't want to try to set it as the post format
        if ([status isKindOfClass:[NSString class]]) {
            if (weakSelf.blog.settings.defaultPostFormat != status) {
                weakSelf.blog.settings.defaultPostFormat = status;

                if ([weakSelf savingWritingDefaultsIsAvailable]) {
                    [WPAnalytics trackSettingsChange:@"site_settings" fieldName:@"default_post_format"];

                    [weakSelf saveSettings];
                }
            }
        }
    };

    [self.navigationController pushViewController:vc animated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectInWritingSectionRow:(NSInteger)row
{
    NSInteger writingRow = [self.writingSectionRows[row] integerValue];
    switch (writingRow) {
        case SiteSettingsWritingDefaultCategory:
            [self showDefaultCategorySelector];
            break;

        case SiteSettingsWritingTags:
            [self showTagList];
            break;

        case SiteSettingsWritingDefaultPostFormat:
            [self showPostFormatSelector];
            break;

        case SiteSettingsWritingRelatedPosts:
            [self showRelatedPostsSettings];
            break;

        case SiteSettingsWritingDateAndTimeFormat:
            [self showDateAndTimeFormatSettings];
            break;

        case SiteSettingsPostPerPage:
            [self showPostPerPageSetting];
            break;

        case SiteSettingsSpeedUpYourSite:
            [self showSpeedUpYourSiteSettings];
            break;
    }
}

- (void)tableView:(UITableView *)tableView didSelectInJetpackSectionRow:(NSInteger)row
{
    switch (row) {
        case SiteSettingsJetpackSecurity:
            [self showJetpackSettingsForBlog:self.blog];
            break;

        case SiteSettingsJetpackConnection:
            [self showJetpackConnectionForBlog:self.blog];
            break;
    }
}

- (void)tableView:(UITableView *)tableView didSelectInAdvancedSectionRow:(NSInteger)row
{
    switch (row) {
        case SiteSettingsAdvancedStartOver:
            [self showStartOverForBlog:self.blog];
            break;

        case SiteSettingsAdvancedExportContent:
            [self confirmExportContent];
            break;

        case SiteSettingsAdvancedDeleteSite:
            [self checkSiteDeletable];
            break;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger settingsSection = [self.tableSections[indexPath.section] intValue];
    switch (settingsSection) {
        case SiteSettingsSectionGeneral:
            [self tableView:tableView didSelectInGeneralSettingsAt:indexPath];
            break;

        case SiteSettingsSectionBlogging:
            [self tableView:tableView didSelectInBloggingSettingsAt:indexPath];
            break;

        case SiteSettingsSectionHomepage:
            [self showHomepageSettingsForBlog:self.blog];

        case SiteSettingsSectionAccount:
            [self tableView:tableView didSelectInAccountSectionRow:indexPath.row];
            break;

        case SiteSettingsSectionWriting:
            [self tableView:tableView didSelectInWritingSectionRow:indexPath.row];
            break;

        case SiteSettingsSectionDiscussion:
            [self showDiscussionSettingsForBlog:self.blog];
            break;

        case SiteSettingsSectionJetpackSettings:
            [self tableView:tableView didSelectInJetpackSectionRow:indexPath.row];
            break;

        case SiteSettingsSectionAdvanced:
            [self tableView:tableView didSelectInAdvancedSectionRow:indexPath.row];

            // UIKit doesn't automatically manage cell selection when a modal presentation is triggered,
            // which is the case for Start Over when there's no paid plan, so we deselect the cell manually.
            if (indexPath.row == SiteSettingsAdvancedStartOver) {
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
            }
            break;
    }
}

#pragma mark - Custom methods

- (IBAction)refreshTriggered:(id)sender
{
    [self refreshData];
}

- (void)refreshData
{
    __weak __typeof__(self) weakSelf = self;
    BlogService *service = [[BlogService alloc] initWithCoreDataStack:[ContextManager sharedInstance]];

    [service syncSettingsForBlog:self.blog success:^{
        [weakSelf.refreshControl endRefreshing];
        self.tableSections = nil; // force the tableSections to be repopulated.
        [weakSelf.tableView reloadData];
    } failure:^(NSError * __unused error) {
        [weakSelf.refreshControl endRefreshing];
    }];

}

#pragma mark - Authentication methods

- (NSString *)getURLToValidate
{
    NSString *urlToValidate = self.blog.url;

    if (![urlToValidate hasPrefix:@"http"]) {
        urlToValidate = [NSString stringWithFormat:@"http://%@", urlToValidate];
    }

    NSError *error = nil;

    NSRegularExpression *wplogin = [NSRegularExpression regularExpressionWithPattern:@"/wp-login.php$" options:NSRegularExpressionCaseInsensitive error:&error];
    NSRegularExpression *wpadmin = [NSRegularExpression regularExpressionWithPattern:@"/wp-admin/?$" options:NSRegularExpressionCaseInsensitive error:&error];
    NSRegularExpression *trailingslash = [NSRegularExpression regularExpressionWithPattern:@"/?$" options:NSRegularExpressionCaseInsensitive error:&error];

    urlToValidate = [wplogin stringByReplacingMatchesInString:urlToValidate options:0 range:NSMakeRange(0, [urlToValidate length]) withTemplate:@""];
    urlToValidate = [wpadmin stringByReplacingMatchesInString:urlToValidate options:0 range:NSMakeRange(0, [urlToValidate length]) withTemplate:@""];
    urlToValidate = [trailingslash stringByReplacingMatchesInString:urlToValidate options:0 range:NSMakeRange(0, [urlToValidate length]) withTemplate:@""];

    return urlToValidate;
}

- (void)validateLoginCredentials
{
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeBlack];
    [SVProgressHUD showWithStatus:NSLocalizedString(@"Authenticating", @"")];

    NSURL *xmlRpcURL = [NSURL URLWithString:self.blog.xmlrpc];
    WordPressOrgXMLRPCApi *api = [[WordPressOrgXMLRPCApi alloc] initWithEndpoint:xmlRpcURL userAgent:[WPUserAgent wordPressUserAgent]];
    __weak __typeof__(self) weakSelf = self;
    [api checkCredentials:self.username password:self.password success:^(id __unused responseObject, NSHTTPURLResponse *__unused httpResponse) {
        [[ContextManager sharedInstance] performAndSaveUsingBlock:^(NSManagedObjectContext *context) {
            __typeof__(self) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            Blog *blogInContext = [context existingObjectWithID:strongSelf.blog.objectID error:nil];
            blogInContext.password = strongSelf.password;
        } completion:^{
            [SVProgressHUD dismiss];
        } onQueue:dispatch_get_main_queue()];
    } failure:^(NSError *error, NSHTTPURLResponse * __unused httpResponse) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
            [weakSelf loginValidationFailedWithError:error];
        });
    }];
}


- (void)loginValidationFailedWithError:(NSError *)error
{
    self.password = self.blog.password;
    if (error) {
        NSString *message;
        if (error.code == 403) {
            message = NSLocalizedString(@"Please try entering your login details again.", @"");
        } else {
            message = [error localizedDescription];
        }
        [WPError showAlertWithTitle:NSLocalizedString(@"Sorry, can't log in", @"Error title when updating the account password fails") message:message];
    }
}

- (NSString *)getTagsCountPresentableString:(NSInteger)tagCount
{
    NSString *format = NSLocalizedString(@"%@ Tags", @"The number of tags in the writting settings. Plural. %@ is a placeholder for the number");

    if (tagCount == 1) {
        format = NSLocalizedString(@"%@ Tag", @"The number of tags in the writting settings. Singular. %@ is a placeholder for the number");
    }

    NSString *numberOfTags = [NSString stringWithFormat: format, @(tagCount)];
    return numberOfTags;
}

#pragma mark - Saving methods

- (void)saveSettings
{
    if (!self.blog.settings.hasChanges) {
        return;
    }

    [self showActivityIndicator];
    BlogService *blogService = [[BlogService alloc] initWithCoreDataStack:[ContextManager sharedInstance]];
    [blogService updateSettingsForBlog:self.blog success:^{
        [self hideActivityIndicator];
        [NSNotificationCenter.defaultCenter postNotificationName:WPBlogSettingsUpdatedNotification object:nil];
    } failure:^(NSError *error) {
        [self hideActivityIndicator];
        [SVProgressHUD showDismissibleErrorWithStatus:NSLocalizedString(@"Settings update failed", @"Message to show when setting save failed")];
        DDLogError(@"Error while trying to update BlogSettings: %@", error);
    }];
}

- (void)showActivityIndicator
{
    if ([self isModal]) {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem.activityIndicator;
    } else {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.activityIndicator;
    }
}

- (void)hideActivityIndicator
{
    if ([self isModal]) {
        self.navigationItem.leftBarButtonItem = nil;
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (BOOL)savingWritingDefaultsIsAvailable
{
    return [self.blog supports:BlogFeatureWPComRESTAPI] && self.blog.isAdmin;
}

- (IBAction)dismiss
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Discussion

- (void)showDiscussionSettingsForBlog:(Blog *)blog
{
    NSParameterAssert(blog);

    DiscussionSettingsViewController *settings = [[DiscussionSettingsViewController alloc] initWithBlog:blog];
    [self.navigationController pushViewController:settings animated:YES];
}

#pragma mark - Jetpack Settings

- (void)showJetpackSettingsForBlog:(Blog *)blog
{

    NSParameterAssert(blog);

    JetpackSettingsViewController *settings = [[JetpackSettingsViewController alloc] initWithBlog:blog];
    [self.navigationController pushViewController:settings animated:YES];
}

- (void)showJetpackConnectionForBlog:(Blog *)blog
{

    NSParameterAssert(blog);

    JetpackConnectionViewController *jetpackConnectionVC = [[JetpackConnectionViewController alloc] initWithBlog:blog];
    jetpackConnectionVC.delegate = self;
    [self.navigationController pushViewController:jetpackConnectionVC animated:YES];
}

#pragma mark - JetpackConnectionViewControllerDelegate

- (void)jetpackDisconnectedForBlog:(Blog *)blog
{
    if (blog == self.blog) {
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}

#pragma mark - PostCategoriesViewControllerDelegate

- (void)postCategoriesViewController:(PostCategoriesViewController *)controller
                   didSelectCategory:(PostCategory *)category
{
    self.blog.settings.defaultCategoryID = category.categoryID;
    self.defaultCategoryCell.detailTextLabel.text = category.categoryName;
    if ([self savingWritingDefaultsIsAvailable]) {
        [WPAnalytics trackSettingsChange:@"site_settings"
                               fieldName:@"default_category"];

        [self saveSettings];
    }
}

#pragma mark - Notification handlers

- (void)handleDataModelChange:(NSNotification *)note
{
    NSSet *updatedObjects = note.userInfo[NSUpdatedObjectsKey];
    if ([updatedObjects containsObject:self.blog]) {
        [self.tableView reloadData];
    }
}

- (void)handleAccountChange:(NSNotification *)notification
{
    [self.tableView reloadData];
}

@end
