#import "PostServiceRemoteREST.h"
#import "RemotePost.h"
#import "RemotePostCategory.h"
#import "RemoteUser.h"
#import "WPKit-Swift.h"
@import WordPressShared;
@import NSObject_SafeExpectations;

NSString * const PostRemoteStatusPublish = @"publish";
NSString * const PostRemoteStatusScheduled = @"future";

static NSString * const RemoteOptionKeyNumber = @"number";
static NSString * const RemoteOptionKeyOffset = @"offset";
static NSString * const RemoteOptionKeyOrder = @"order";
static NSString * const RemoteOptionKeyOrderBy = @"order_by";
static NSString * const RemoteOptionKeyStatus = @"status";
static NSString * const RemoteOptionKeySearch = @"search";
static NSString * const RemoteOptionKeyAuthor = @"author";
static NSString * const RemoteOptionKeyMeta = @"meta";
static NSString * const RemoteOptionKeyTag = @"tag";

static NSString * const RemoteOptionValueOrderAscending = @"ASC";
static NSString * const RemoteOptionValueOrderDescending = @"DESC";
static NSString * const RemoteOptionValueOrderByDate = @"date";
static NSString * const RemoteOptionValueOrderByModified = @"modified";
static NSString * const RemoteOptionValueOrderByTitle = @"title";
static NSString * const RemoteOptionValueOrderByCommentCount = @"comment_count";
static NSString * const RemoteOptionValueOrderByPostID = @"ID";

@implementation PostServiceRemoteREST

- (void)getPostWithID:(NSNumber *)postID
              success:(void (^)(RemotePost *post))success
              failure:(void (^)(NSError *))failure
{
    NSParameterAssert(postID);

    NSString *path = [NSString stringWithFormat:@"sites/%@/posts/%@", self.siteID, postID];
    NSString *requestUrl = [self pathForEndpoint:path
                                     withVersion:WordPressComRESTAPIVersion_1_1];
    
    NSDictionary *parameters = @{ @"context": @"edit" };
    
    [self.wordPressComRESTAPI get:requestUrl
       parameters:parameters
          success:^(id responseObject, NSHTTPURLResponse *httpResponse) {
              if (success) {
                  success([self remotePostFromJSONDictionary:responseObject]);
              }
          } failure:^(NSError *error, NSHTTPURLResponse *httpResponse) {
              if (failure) {
                  failure(error);
              }
          }];
}

- (void)getPostsOfType:(NSString *)postType
               success:(void (^)(NSArray <RemotePost *> *remotePosts))success
               failure:(void (^)(NSError *))failure
{
    [self getPostsOfType:postType options:nil success:success failure:failure];
}

- (void)getPostsOfType:(NSString *)postType
               options:(NSDictionary *)options
               success:(void (^)(NSArray <RemotePost *> *remotePosts))success
               failure:(void (^)(NSError *))failure
{
    NSParameterAssert([postType isKindOfClass:[NSString class]]);

    NSString *path = [NSString stringWithFormat:@"sites/%@/posts", self.siteID];
    NSString *requestUrl = [self pathForEndpoint:path
                                     withVersion:WordPressComRESTAPIVersion_1_2];
    
    NSDictionary *parameters = @{
                                 @"status": @"any,trash",
                                 @"context": @"edit",
                                 @"number": @40,
                                 @"type": postType,
                                 };
    if (options) {
        NSMutableDictionary *mutableParameters = [parameters mutableCopy];
        [mutableParameters addEntriesFromDictionary:options];
        parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    }
    [self.wordPressComRESTAPI get:requestUrl
       parameters:parameters
          success:^(id responseObject, NSHTTPURLResponse *httpResponse) {
              if (success) {
                  success([self remotePostsFromJSONArray:responseObject[@"posts"]]);
              }
          } failure:^(NSError *error, NSHTTPURLResponse *httpResponse) {
              if (failure) {
                  failure(error);
              }
          }];
}

-(void)getAutoSaveForPost:(RemotePost *)post
                  success:(void (^)(RemotePost *))success
                  failure:(void (^)(NSError *error))failure
{
    NSString *path = [NSString stringWithFormat:@"sites/%@/posts/%@/autosave", self.siteID, post.postID];
    NSString *requestUrl = [self pathForEndpoint:path
                                     withVersion:WordPressComRESTAPIVersion_1_1];
    
    NSDictionary *parameters = [self parametersWithRemotePost:post];
    
    [self.wordPressComRESTAPI get:requestUrl
                       parameters:parameters
                          success:^(id responseObject, NSHTTPURLResponse *httpResponse) {
                              RemotePost *post = [self remotePostFromJSONDictionary:responseObject];
                              if (success) {
                                  success(post);
                              }
                          } failure:^(NSError *error, NSHTTPURLResponse *httpResponse) {
                              if (failure) {
                                  failure(error);
                              }
                          }];
}

- (void)createPost:(RemotePost *)post
           success:(void (^)(RemotePost *))success
           failure:(void (^)(NSError *))failure
{
    NSParameterAssert([post isKindOfClass:[RemotePost class]]);

    NSString *path = [NSString stringWithFormat:@"sites/%@/posts/new?context=edit", self.siteID];
    NSString *requestUrl = [self pathForEndpoint:path
                                     withVersion:WordPressComRESTAPIVersion_1_2];
    
    NSDictionary *parameters = [self parametersWithRemotePost:post];

    [self.wordPressComRESTAPI post:requestUrl
        parameters:parameters
           success:^(id responseObject, NSHTTPURLResponse *httpResponse) {
               RemotePost *post = [self remotePostFromJSONDictionary:responseObject];
               if (success) {
                   success(post);
               }
           } failure:^(NSError *error, NSHTTPURLResponse *httpResponse) {
               if (failure) {
                   failure(error);
               }
           }];
}

- (void)createPost:(RemotePost *)post
         withMedia:(RemoteMedia *)media
   requestEnqueued:(void (^)(NSNumber *taskID))requestEnqueued
           success:(void (^)(RemotePost *))success
           failure:(void (^)(NSError *))failure
{
    NSParameterAssert([post isKindOfClass:[RemotePost class]]);

    NSString *type = media.mimeType;
    NSString *filename = media.file;
    NSString *path = [NSString stringWithFormat:@"sites/%@/posts/new", self.siteID];
    NSString *requestUrl = [self pathForEndpoint:path
                                     withVersion:WordPressComRESTAPIVersion_1_2];

    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:@{}];
    parameters[@"content"] = post.content;
    parameters[@"title"] = post.title;
    parameters[@"status"] = post.status;
    FilePart *filePart = [[FilePart alloc] initWithParameterName:@"media[]" url:media.localURL fileName:filename mimeType:type];
    [self.wordPressComRESTAPI multipartPOST:requestUrl
                                 parameters:parameters
                                  fileParts:@[filePart]
                            requestEnqueued:^(NSNumber *taskID) {
                                if (requestEnqueued) {
                                    requestEnqueued(taskID);
                                }
    } success:^(id  _Nonnull responseObject, NSHTTPURLResponse * _Nullable httpResponse) {
        RemotePost *post = [self remotePostFromJSONDictionary:responseObject];
        if (success) {
            success(post);
        }
    } failure:^(NSError *error, NSHTTPURLResponse *httpResponse) {
        if (failure) {
            failure(error);
        }
    }];
}

- (void)updatePost:(RemotePost *)post
           success:(void (^)(RemotePost *))success
           failure:(void (^)(NSError *))failure
{
    NSParameterAssert([post isKindOfClass:[RemotePost class]]);

    NSString *path = [NSString stringWithFormat:@"sites/%@/posts/%@?context=edit", self.siteID, post.postID];
    NSString *requestUrl = [self pathForEndpoint:path
                                     withVersion:WordPressComRESTAPIVersion_1_2];
    
    NSDictionary *parameters = [self parametersWithRemotePost:post];

    [self.wordPressComRESTAPI post:requestUrl
        parameters:parameters
           success:^(id responseObject, NSHTTPURLResponse *httpResponse) {
               RemotePost *post = [self remotePostFromJSONDictionary:responseObject];
               if (success) {
                   success(post);
               }
           } failure:^(NSError *error, NSHTTPURLResponse *httpResponse) {
               if (failure) {
                   failure(error);
               }
           }];
}

- (void)autoSave:(RemotePost *)post
         success:(void (^)(RemotePost *, NSString *))success
         failure:(void (^)(NSError *))failure
{
    NSParameterAssert([post isKindOfClass:[RemotePost class]]);
    
    NSString *path = [NSString stringWithFormat:@"sites/%@/posts/%@/autosave", self.siteID, post.postID];
    NSString *requestUrl = [self pathForEndpoint:path
                                     withVersion:WordPressComRESTAPIVersion_1_1];
    
    NSDictionary *parameters = [self parametersWithRemotePost:post];
    
    [self.wordPressComRESTAPI post:requestUrl
                        parameters:parameters
                           success:^(id responseObject, NSHTTPURLResponse *httpResponse) {
                               RemotePost *post = [self remotePostFromJSONDictionary:responseObject];
                               NSString *previewURL = responseObject[@"preview_URL"];
                               if (success) {
                                   success(post, previewURL);
                               }
                           } failure:^(NSError *error, NSHTTPURLResponse *httpResponse) {
                               if (failure) {
                                   failure(error);
                               }
                           }];
}

- (void)deletePost:(RemotePost *)post
           success:(void (^)(void))success
           failure:(void (^)(NSError *))failure
{
    NSParameterAssert([post isKindOfClass:[RemotePost class]]);

    NSString *path = [NSString stringWithFormat:@"sites/%@/posts/%@/delete", self.siteID, post.postID];
    NSString *requestUrl = [self pathForEndpoint:path
                                     withVersion:WordPressComRESTAPIVersion_1_1];
    
    [self.wordPressComRESTAPI post:requestUrl
        parameters:nil
           success:^(id responseObject, NSHTTPURLResponse *httpResponse) {
               if (success) {
                   success();
               }
           } failure:^(NSError *error, NSHTTPURLResponse *httpResponse) {
               if (failure) {
                   failure(error);
               }
           }];
}

- (void)trashPost:(RemotePost *)post
          success:(void (^)(RemotePost *))success
          failure:(void (^)(NSError *))failure
{
    NSParameterAssert([post isKindOfClass:[RemotePost class]]);

    // The parameters are passed as part of the string here because AlamoFire doesn't encode parameters on POST requests.
    NSString *path = [NSString stringWithFormat:@"sites/%@/posts/%@/delete?context=edit", self.siteID, post.postID];
    NSString *requestUrl = [self pathForEndpoint:path
                                     withVersion:WordPressComRESTAPIVersion_1_1];
    
    [self.wordPressComRESTAPI post:requestUrl
        parameters:nil
           success:^(id responseObject, NSHTTPURLResponse *httpResponse) {
               RemotePost *post = [self remotePostFromJSONDictionary:responseObject];
               if (success) {
                   success(post);
               }
           } failure:^(NSError *error, NSHTTPURLResponse *httpResponse) {
               if (failure) {
                   failure(error);
               }
           }];
}

- (void)restorePost:(RemotePost *)post
            success:(void (^)(RemotePost *))success
            failure:(void (^)(NSError *))failure
{
    NSParameterAssert([post isKindOfClass:[RemotePost class]]);

    // The parameters are passed as part of the string here because AlamoFire doesn't encode parameters on POST requests.
    // https://github.com/wordpress-mobile/WordPressKit-iOS/pull/385
    NSString *path = [NSString stringWithFormat:@"sites/%@/posts/%@/restore?context=edit", self.siteID, post.postID];
    NSString *requestUrl = [self pathForEndpoint:path
                                     withVersion:WordPressComRESTAPIVersion_1_1];
    
    [self.wordPressComRESTAPI post:requestUrl
        parameters:nil
           success:^(id responseObject, NSHTTPURLResponse *httpResponse) {
               RemotePost *post = [self remotePostFromJSONDictionary:responseObject];
               if (success) {
                   success(post);
               }
           } failure:^(NSError *error, NSHTTPURLResponse *httpResponse) {
               if (failure) {
                   failure(error);
               }
           }];
}

- (void)getLikesForPostID:(NSNumber *)postID
                    count:(NSNumber *)count
                   before:(NSString *)before
           excludeUserIDs:(NSArray<NSNumber *> *)excludeUserIDs
                  success:(void (^)(NSArray<RemoteLikeUser *> * _Nonnull users, NSNumber *found))success
                  failure:(void (^)(NSError * _Nullable))failure
{
    NSParameterAssert(postID);

    NSString *path = [NSString stringWithFormat:@"sites/%@/posts/%@/likes", self.siteID, postID];
    NSString *requestUrl = [self pathForEndpoint:path
                                     withVersion:WordPressComRESTAPIVersion_1_2];
    NSNumber *siteID = self.siteID;

    // If no count provided, default to endpoint max.
    if (count == 0) {
        count = @90;
    }
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:@{ @"number": count }];
    
    if (before) {
        parameters[@"before"] = before;
    }
    
    if (excludeUserIDs) {
        parameters[@"exclude"] = excludeUserIDs;
    }

    [self.wordPressComRESTAPI get:requestUrl
                       parameters:parameters
                          success:^(id responseObject, NSHTTPURLResponse *httpResponse) {
        if (success) {
            NSArray *jsonUsers = responseObject[@"likes"] ?: @[];
            NSArray<RemoteLikeUser *> *users = [self remoteUsersFromJSONArray:jsonUsers postID:postID siteID:siteID];
            NSNumber *found = [responseObject numberForKey:@"found"] ?: @0;
            success(users, found);
        }
    } failure:^(NSError *error, NSHTTPURLResponse *httpResponse) {
        if (failure) {
            failure(error);
        }
    }];
}

- (NSDictionary *)dictionaryWithRemoteOptions:(id <PostServiceRemoteOptions>)options
{
    NSMutableDictionary *remoteParams = [NSMutableDictionary dictionary];
    if (options.number) {
        [remoteParams setObject:options.number forKey:RemoteOptionKeyNumber];
    }
    if (options.offset) {
        [remoteParams setObject:options.offset forKey:RemoteOptionKeyOffset];
    }
    
    NSString *statusesStr = nil;
    if (options.statuses.count) {
        statusesStr = [options.statuses componentsJoinedByString:@","];
    }
    if (options.order) {
        NSString *orderStr = nil;
        switch (options.order) {
            case PostServiceResultsOrderDescending:
                orderStr = RemoteOptionValueOrderDescending;
                break;
            case PostServiceResultsOrderAscending:
                orderStr = RemoteOptionValueOrderAscending;
                break;
        }
        [remoteParams setObject:orderStr forKey:RemoteOptionKeyOrder];
    }
    
    NSString *orderByStr = nil;
    if (options.orderBy) {
        switch (options.orderBy) {
            case PostServiceResultsOrderingByDate:
                orderByStr = RemoteOptionValueOrderByDate;
                break;
            case PostServiceResultsOrderingByModified:
                orderByStr = RemoteOptionValueOrderByModified;
                break;
            case PostServiceResultsOrderingByTitle:
                orderByStr = RemoteOptionValueOrderByTitle;
                break;
            case PostServiceResultsOrderingByCommentCount:
                orderByStr = RemoteOptionValueOrderByCommentCount;
                break;
            case PostServiceResultsOrderingByPostID:
                orderByStr = RemoteOptionValueOrderByPostID;
                break;
        }
    }
    
    if (statusesStr.length) {
        [remoteParams setObject:statusesStr forKey:RemoteOptionKeyStatus];
    }
    if (orderByStr.length) {
        [remoteParams setObject:orderByStr forKey:RemoteOptionKeyOrderBy];
    }
    if (options.authorID) {
        [remoteParams setObject:options.authorID forKey:RemoteOptionKeyAuthor];
    }
    if (options.search.length > 0) {
        [remoteParams setObject:options.search forKey:RemoteOptionKeySearch];
    }
    if (options.meta.length > 0) {
        [remoteParams setObject:options.meta forKey:RemoteOptionKeyMeta];
    }
    if ([options respondsToSelector:@selector(tag)] && options.tag.length > 0) {
        [remoteParams setObject:options.tag forKey:RemoteOptionKeyTag];
    }

    return remoteParams.count ? [NSDictionary dictionaryWithDictionary:remoteParams] : nil;
}

#pragma mark - Private methods

- (NSArray *)remotePostsFromJSONArray:(NSArray *)jsonPosts {
    return [jsonPosts wp_map:^id(NSDictionary *jsonPost) {
        return [self remotePostFromJSONDictionary:jsonPost];
    }];
}

- (RemotePost *)remotePostFromJSONDictionary:(NSDictionary *)jsonPost {
    return [PostServiceRemoteREST remotePostFromJSONDictionary:jsonPost];
}

+ (RemotePost *)remotePostFromJSONDictionary:(NSDictionary *)jsonPost {
    RemotePost *post = [RemotePost new];
    post.postID = jsonPost[@"ID"];
    post.siteID = jsonPost[@"site_ID"];
    if (jsonPost[@"author"] != [NSNull null]) {
        NSDictionary *authorDictionary = jsonPost[@"author"];
        post.authorAvatarURL = authorDictionary[@"avatar_URL"];
        post.authorDisplayName = authorDictionary[@"name"];
        post.authorEmail = [authorDictionary stringForKey:@"email"];
        post.authorURL = authorDictionary[@"URL"];
    }
    post.authorID = [jsonPost numberForKeyPath:@"author.ID"];
    post.date = [NSDate dateWithWordPressComJSONString:jsonPost[@"date"]];
    post.dateModified = [NSDate dateWithWordPressComJSONString:jsonPost[@"modified"]];
    post.title = jsonPost[@"title"];
    post.URL = [NSURL URLWithString:jsonPost[@"URL"]];
    post.shortURL = [NSURL URLWithString:jsonPost[@"short_URL"]];
    post.content = jsonPost[@"content"];
    post.excerpt = jsonPost[@"excerpt"];
    post.slug = jsonPost[@"slug"];
    post.suggestedSlug = [jsonPost stringForKeyPath:@"other_URLs.suggested_slug"];
    post.status = jsonPost[@"status"];
    post.password = jsonPost[@"password"];
    if ([post.password isEmpty]) {
        post.password = nil;
    }
    post.parentID = [jsonPost numberForKeyPath:@"parent.ID"];
    // post_thumbnail can be null, which will transform to NSNull, so we need to add the extra check
    NSDictionary *postThumbnail = [jsonPost dictionaryForKey:@"post_thumbnail"];
    post.postThumbnailID = [postThumbnail numberForKey:@"ID"];
    post.postThumbnailPath = [postThumbnail stringForKeyPath:@"URL"];
    post.type = jsonPost[@"type"];
    post.format = jsonPost[@"format"];

    post.commentCount = [jsonPost numberForKeyPath:@"discussion.comment_count"] ?: @0;
    post.likeCount = [jsonPost numberForKeyPath:@"like_count"] ?: @0;

    post.isStickyPost = [jsonPost numberForKeyPath:@"sticky"];
    
    // FIXME: remove conversion once API is fixed #38-io
    // metadata should always be an array but it's returning false when there are no custom fields
    post.metadata = [jsonPost arrayForKey:@"metadata"];
    // Or even worse, in some cases (Jetpack sites?) is an array containing false
    post.metadata = [post.metadata filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject isKindOfClass:[NSDictionary class]];
    }]];
    // post.metadata = jsonPost[@"metadata"];

    NSDictionary *categories = jsonPost[@"categories"];
    if (categories) {
        post.categories = [self remoteCategoriesFromJSONArray:[categories allValues]];
    }
    post.tags = [self tagNamesFromJSONDictionary:jsonPost[@"tags"]];

    post.revisions = [jsonPost arrayForKey:@"revisions"];

    NSDictionary *autosaveAttributes = jsonPost[@"meta"][@"data"][@"autosave"];
    if ([autosaveAttributes wp_isValidObject]) {
        RemotePostAutosave *autosave = [[RemotePostAutosave alloc] init];
        autosave.title = autosaveAttributes[@"title"];
        autosave.content = autosaveAttributes[@"content"];
        autosave.excerpt = autosaveAttributes[@"excerpt"];
        autosave.modifiedDate = [NSDate dateWithWordPressComJSONString:autosaveAttributes[@"modified"]];
        autosave.identifier = autosaveAttributes[@"ID"];
        autosave.authorID = autosaveAttributes[@"author_ID"];
        autosave.postID = autosaveAttributes[@"post_ID"];
        autosave.previewURL = autosaveAttributes[@"preview_URL"];
        post.autosave = autosave;
    }

    // Pick an image to use for display
    if (post.postThumbnailPath) {
        post.pathForDisplayImage = post.postThumbnailPath;
    } else {
        // parse contents for a suitable image
        post.pathForDisplayImage = [DisplayableImageHelper searchPostContentForImageToDisplay:post.content];
        if ([post.pathForDisplayImage length] == 0) {
            post.pathForDisplayImage = [DisplayableImageHelper searchPostAttachmentsForImageToDisplay:[jsonPost dictionaryForKey:@"attachments"] existingInContent:post.content];
        }
    }

    return post;
}

- (NSDictionary *)parametersWithRemotePost:(RemotePost *)post
{
    NSParameterAssert(post.title != nil);
    NSParameterAssert(post.content != nil);
    BOOL existingPost = ([post.postID longLongValue] > 0);
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    if (post.title) {
        parameters[@"title"] = post.title;
    } else {
        parameters[@"title"] = @"";
    }
    
    parameters[@"content"] = post.content;
    parameters[@"password"] = post.password ? post.password : @"";
    parameters[@"type"] = post.type;

    if (post.date) {
        parameters[@"date"] = [post.date WordPressComJSONString];
    } else if (existingPost) {
        // safety net. An existing post with no create date should publish immediately
        parameters[@"date"] = [[NSDate date] WordPressComJSONString];
    }
    if (post.excerpt) {
        parameters[@"excerpt"] = post.excerpt;
    }
    if (post.slug) {
        parameters[@"slug"] = post.slug;
    }

    if (post.authorID) {
        parameters[@"author"] = post.authorID;
    }

    if (post.categories) {
        parameters[@"categories_by_id"] = [post.categories valueForKey:@"categoryID"];
    }

    if (post.tags) {
        NSArray *tags = post.tags;
        NSDictionary *postTags = @{@"post_tag":tags};
        parameters[@"terms"] = postTags;
    }
    if (post.format) {
        parameters[@"format"] = post.format;
    }

    parameters[@"parent"] = post.parentID ?: @"false";
    parameters[@"featured_image"] = post.postThumbnailID ? [post.postThumbnailID stringValue] : @"";

    NSArray *metadata = [self metadataForPost:post];
    if (metadata.count > 0) {
        parameters[@"metadata"] = metadata;
    }
    
    if (post.isStickyPost != nil) {
        parameters[@"sticky"] = post.isStickyPost.boolValue ? @"true" : @"false";
    }

    // Scheduled posts need to sync with a status of 'publish'.
    // Passing a status of 'future' will set the post status to 'draft'
    // This is an apparent inconsistency in the API as 'future' should
    // be a valid status.
    if ([post.status isEqualToString:PostRemoteStatusScheduled]) {
        post.status = PostRemoteStatusPublish;
    }
    parameters[@"status"] = post.status;

    // Test what happens for nil and not present values
    return [NSDictionary dictionaryWithDictionary:parameters];
}

- (NSArray *)metadataForPost:(RemotePost *)post {
    return [post.metadata wp_map:^id(NSDictionary *meta) {
        NSNumber *metaID = [meta objectForKey:@"id"];
        NSString *metaValue = [meta objectForKey:@"value"];
        NSString *metaKey = [meta objectForKey:@"key"];
        NSString *operation = @"update";

        if (!metaKey) {
            if (metaID && !metaValue) {
                operation = @"delete";
            } else if (!metaID && metaValue) {
                operation = @"add";
            }
        }

        NSMutableDictionary *modifiedMeta = [meta mutableCopy];
        modifiedMeta[@"operation"] = operation;
        return [NSDictionary dictionaryWithDictionary:modifiedMeta];
    }];
}

+ (NSArray *)remoteCategoriesFromJSONArray:(NSArray *)jsonCategories {
    return [jsonCategories wp_map:^id(NSDictionary *jsonCategory) {
        return [self remoteCategoryFromJSONDictionary:jsonCategory];
    }];
}

+ (RemotePostCategory *)remoteCategoryFromJSONDictionary:(NSDictionary *)jsonCategory {
    RemotePostCategory *category = [RemotePostCategory new];
    category.categoryID = jsonCategory[@"ID"];
    category.name = jsonCategory[@"name"];
    category.parentID = jsonCategory[@"parent"];

    return category;
}

+ (NSArray *)tagNamesFromJSONDictionary:(NSDictionary *)jsonTags {
    return [jsonTags allKeys];
}

/**
 *  @brief  Returns an array of RemoteLikeUser based on provided JSON
 *          representation of users.
 *
 *  @param  jsonUsers   An array containing JSON representations of users.
 *  @param  postID      ID of the Post the users liked.
 *  @param  siteID      ID of the Post's site.
 */
- (NSArray<RemoteLikeUser *> *)remoteUsersFromJSONArray:(NSArray *)jsonUsers
                                                 postID:(NSNumber *)postID
                                                 siteID:(NSNumber *)siteID
{
    return [jsonUsers wp_map:^id(NSDictionary *jsonUser) {
        return [[RemoteLikeUser alloc] initWithDictionary:jsonUser postID:postID siteID:siteID];
    }];
}

@end
