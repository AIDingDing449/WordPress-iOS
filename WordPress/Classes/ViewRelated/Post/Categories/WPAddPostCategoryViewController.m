#import "WPAddPostCategoryViewController.h"
#import "Blog.h"
#import "PostCategory.h"
#import "Constants.h"
#import "SiteSettingsViewController.h"
#import "PostCategoryService.h"
#import "CoreDataStack.h"
#import "BlogService.h"
#import "WordPress-Swift.h"

@import WordPressShared;

@interface WPAddPostCategoryViewController ()<PostCategoriesViewControllerDelegate, UITextFieldDelegate>

@property (nonatomic, strong) PostCategory *parentCategory;
@property (nonatomic, strong) Blog *blog;
@property (nonatomic, strong) WPTextFieldTableViewCell *createCategoryCell;
@property (nonatomic, strong) WPTableViewCell *parentCategoryCell;
@property (nonatomic, strong) UIBarButtonItem *saveButtonItem;

@end

@implementation WPAddPostCategoryViewController

- (instancetype)initWithBlog:(Blog *)blog
{
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _blog = blog;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = NSLocalizedString(@"Add a Category", @"The title on the add category screen");
    self.tableView.sectionFooterHeight = 0.0f;
    // Set this to 0 to avoid automattic sizing of cells and getting label cell to short.
    self.tableView.estimatedRowHeight = 0.0f;
    self.view.tintColor = [UIColor murielEditorPrimary];

    self.saveButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Save", @"Save button label (saving content, ex: Post, Page, Comment, Category).") style:UIBarButtonItemStylePlain target:self action:@selector(saveAddCategory:)];

    self.navigationItem.rightBarButtonItem = self.saveButtonItem;

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self action:@selector(dismiss:)];
    [WPStyleGuide configureColorsForView:self.view andTableView:self.tableView];
}

#pragma mark - Instance Methods

- (void)clearUI
{
    self.createCategoryCell.textField.text = @"";
    self.parentCategoryCell.textLabel.text = @"";
}

- (void)addProgressIndicator
{
    UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    UIBarButtonItem *activityButtonItem = [[UIBarButtonItem alloc] initWithCustomView:activityView];
    [activityView startAnimating];

    self.navigationItem.rightBarButtonItem = activityButtonItem;
}

- (void)removeProgressIndicator
{
    self.navigationItem.rightBarButtonItem = self.saveButtonItem;
}

- (IBAction)dismiss:(id)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)saveAddCategory:(id)sender
{
    NSManagedObjectContext *context = [[ContextManager sharedInstance] mainContext];
    PostCategoryService *categoryService = [[PostCategoryService alloc] initWithCoreDataStack:[ContextManager sharedInstance]];
    NSString *catName = [self.createCategoryCell.textField.text trim];

    if (!catName ||[catName length] == 0) {
        NSString *title = NSLocalizedString(@"Category title missing.", @"Error popup title to indicate that there was no category title filled in.");
        NSString *message = NSLocalizedString(@"Title for a category is mandatory.", @"Error popup message to indicate that there was no category title filled in.");
        [WPError showAlertWithTitle:title message:message withSupportButton:NO];
        self.createCategoryCell.textField.text = @""; // To clear whitespace that was trimed.

        return;
    }

    PostCategory *category = [PostCategory lookupWithBlogObjectID:self.blog.objectID
                                                 parentCategoryID:self.parentCategory.categoryID
                                                     categoryName:catName
                                                        inContext:context];
    if (category) {
        // If there's an existing category with that name and parent, let's use that
        [self dismissWithCategory:category];
        return;
    }

    [self addProgressIndicator];

    [categoryService createCategoryWithName:catName
                     parentCategoryObjectID:self.parentCategory.objectID
                            forBlogObjectID:self.blog.objectID
                                    success:^(PostCategory *category) {
                                        [self removeProgressIndicator];
                                        [self dismissWithCategory:category];
                                    } failure:^(NSError *error) {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [self removeProgressIndicator];

                                            if ([error code] == 403) {
                                                [WPError showAlertWithTitle:NSLocalizedString(@"Couldn't Connect", @"") message:NSLocalizedString(@"The username or password stored in the app may be out of date. Please re-enter your password in the settings and try again.", @"") withSupportButton:NO];

                                                // bad login/pass combination
                                                SiteSettingsViewController *editSiteViewController = [[SiteSettingsViewController alloc] initWithBlog:self.blog];
                                                [self.navigationController pushViewController:editSiteViewController animated:YES];

                                            } else {
                                                [WPError showXMLRPCErrorAlert:error];
                                            }
                                        });
                                    }];
}

- (void)dismissWithCategory:(PostCategory *)category
{
    // Add the newly created category to the post
    if ([self.delegate respondsToSelector:@selector(addPostCategoryViewController:didAddCategory:)]) {
        [self.delegate addPostCategoryViewController:self didAddCategory:category];
    }

    // Cleanup and dismiss
    [self clearUI];
    [self dismiss:nil];
}

#pragma mark - functional methods

- (void)showParentCategorySelector
{
    NSArray<PostCategory*>* currentSelection = self.parentCategory ? @[self.parentCategory] : nil;
    
    PostCategoriesViewController *controller = [[PostCategoriesViewController alloc] initWithBlog:self.blog
                                                                                 currentSelection:currentSelection
                                                                                    selectionMode:CategoriesSelectionModeParent];
    controller.delegate = self;
    [self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - tableviewDelegates/datasources

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    WPTableViewCell *cell;
    if (indexPath.section == 0) {
        cell = self.createCategoryCell;
    } else {
        cell = self.parentCategoryCell;
    }
    return cell;
}

- (WPTextFieldTableViewCell *)createCategoryCell
{
    if (_createCategoryCell) {
        return _createCategoryCell;
    }
    _createCategoryCell = [[WPTextFieldTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
         
    _createCategoryCell.textField.clearButtonMode = UITextFieldViewModeAlways;
    _createCategoryCell.textField.font = [WPStyleGuide tableviewTextFont];
    _createCategoryCell.textField.textColor = [UIColor murielNeutral70];
    _createCategoryCell.textField.text = @"";
    _createCategoryCell.textField.placeholder = NSLocalizedString(@"Title", @"Title of the new Category being created.");;
    _createCategoryCell.textField.returnKeyType = UIReturnKeyDone;
    _createCategoryCell.textField.keyboardType = UIKeyboardTypeDefault;
    _createCategoryCell.textField.secureTextEntry = NO;
    _createCategoryCell.textField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _createCategoryCell.textField.delegate = self;
    
    return _createCategoryCell;
}

- (WPTableViewCell *)parentCategoryCell
{
    if (!_parentCategoryCell) {
        _parentCategoryCell = [[WPTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        _parentCategoryCell.textLabel.text = NSLocalizedString(@"Parent Category", @"Placeholder to set a parent category for a new category.");
        _parentCategoryCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        [WPStyleGuide configureTableViewCell:_parentCategoryCell];
    }
    
    NSString *parentCategoryName;
    if (self.parentCategory == nil ) {
        parentCategoryName = NSLocalizedString(@"Optional", @"Placeholder to indicate that filling out the field is optional.");
    } else {
        parentCategoryName = self.parentCategory.categoryName;
    }
    _parentCategoryCell.detailTextLabel.text = parentCategoryName;

    return _parentCategoryCell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];

    if (indexPath.section == 1) {
        [self showParentCategorySelector];
    }
}

#pragma mark textfied deletage

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - PostCategoriesViewControllerDelegate methods

- (void)postCategoriesViewController:(PostCategoriesViewController *)controller didSelectCategory:(PostCategory *)category
{
    self.parentCategory = category;
    [self.tableView reloadData];
}

@end
