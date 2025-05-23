#import "Media.h"
#ifdef KEYSTONE
#import "Keystone-Swift.h"
#else
#import "WordPress-Swift.h"
#endif

@implementation Media

@dynamic alt;
@dynamic mediaID;
@dynamic remoteURL;
@dynamic remoteLargeURL;
@dynamic remoteMediumURL;
@dynamic localURL;
@dynamic shortcode;
@dynamic width;
@dynamic length;
@dynamic title;
@dynamic height;
@dynamic filename;
@dynamic filesize;
@dynamic creationDate;
@dynamic blog;
@dynamic posts;
@dynamic remoteStatusNumber;
@dynamic caption;
@dynamic desc;
@dynamic mediaTypeString;
@dynamic videopressGUID;
@dynamic localThumbnailIdentifier;
@dynamic localThumbnailURL;
@dynamic remoteThumbnailURL;
@dynamic postID;
@dynamic error;
@dynamic featuredOnPosts;
@dynamic autoUploadFailureCount;

#pragma mark -

+ (NSString *)stringFromMediaType:(MediaType)mediaType
{
    switch (mediaType) {
        case MediaTypeImage:
            return @"image";
            break;
        case MediaTypeVideo:
            return @"video";
            break;
        case MediaTypePowerpoint:
            return @"powerpoint";
            break;
        case MediaTypeDocument:
            return @"document";
            break;
        case MediaTypeAudio:
            return @"audio";
            break;
    }
}

#pragma mark -

- (NSString *)fileExtension
{
    NSString *extension = [self.filename pathExtension];
    if (extension.length) {
        return extension;
    }
    extension = [self.localURL pathExtension];
    if (extension.length) {
        return extension;
    }
    extension = [self.remoteURL pathExtension];
    return extension;
}

#pragma mark - Media Types

- (MediaType)mediaType
{
    if ([self.mediaTypeString isEqualToString:[Media stringFromMediaType:MediaTypeImage]]) {
        return MediaTypeImage;
    } else if ([self.mediaTypeString isEqualToString:[Media stringFromMediaType:MediaTypeVideo]]) {
        return MediaTypeVideo;
    } else if ([self.mediaTypeString isEqualToString:[Media stringFromMediaType:MediaTypePowerpoint]]) {
        return MediaTypePowerpoint;
    } else if ([self.mediaTypeString isEqualToString:[Media stringFromMediaType:MediaTypeDocument]]) {
        return MediaTypeDocument;
    } else if ([self.mediaTypeString isEqualToString:[Media stringFromMediaType:MediaTypeAudio]]) {
        return MediaTypeAudio;
    }

    return MediaTypeDocument;
}

- (void)setMediaType:(MediaType)mediaType
{
    self.mediaTypeString = [[self class] stringFromMediaType:mediaType];    
}

#pragma mark - Remote Status

- (MediaRemoteStatus)remoteStatus
{
    return (MediaRemoteStatus)[[self remoteStatusNumber] intValue];
}

- (void)setRemoteStatus:(MediaRemoteStatus)aStatus
{
    [self setRemoteStatusNumber:@(aStatus)];
}

- (NSString *)remoteStatusText
{
    switch (self.remoteStatus) {
        case MediaRemoteStatusPushing:
            return NSLocalizedString(@"Uploading", @"Status for Media object that is being uploaded.");
        case MediaRemoteStatusFailed:
            return NSLocalizedString(@"Failed", @"Status for Media object that is failed upload or export.");
        case MediaRemoteStatusSync:
            return NSLocalizedString(@"Uploaded", @"Status for Media object that is uploaded and sync with server.");
        case MediaRemoteStatusProcessing:
            return NSLocalizedString(@"Pending", @"Status for Media object that is being processed locally.");
        case MediaRemoteStatusLocal:
            return NSLocalizedString(@"Local", @"Status for Media object that is only exists locally.");
        case MediaRemoteStatusStub:
            return NSLocalizedString(@"Stub", @"Status for Media object that is only has the mediaID locally.");
    }
}

#pragma mark - Absolute URLs

- (NSURL *)absoluteThumbnailLocalURL;
{
    if (!self.localThumbnailURL.length) {
        return nil;
    }
    return [self absoluteURLForLocalPath:self.localThumbnailURL cacheDirectory:YES];
}

- (void)setAbsoluteThumbnailLocalURL:(NSURL *)absoluteLocalURL
{
    self.localThumbnailURL = absoluteLocalURL.lastPathComponent;
}

- (NSURL *)absoluteLocalURL
{
    if (!self.localURL.length) {
        return nil;
    }
    return [self absoluteURLForLocalPath:self.localURL cacheDirectory:NO];
}

- (void)setAbsoluteLocalURL:(NSURL *)absoluteLocalURL
{
    self.localURL = absoluteLocalURL.lastPathComponent;
}

- (NSURL *)absoluteURLForLocalPath:(NSString *)localPath cacheDirectory:(BOOL)cacheDirectory
{
    NSError *error;
    NSURL *mediaDirectory = nil;
    if (cacheDirectory) {
        mediaDirectory = [[MediaFileManager cacheManager] directoryURLAndReturnError:&error];
    } else {
        mediaDirectory = [MediaFileManager uploadsDirectoryURLAndReturnError:&error];
    }
    if (error) {
        DDLogInfo(@"Error resolving Media directory: %@", error);
        return nil;
    }
    return [mediaDirectory URLByAppendingPathComponent:localPath.lastPathComponent];
}

#pragma mark - CoreData Helpers

- (void)prepareForDeletion
{
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *absolutePath = self.absoluteLocalURL.path;
    if ([fileManager fileExistsAtPath:absolutePath] &&
        ![fileManager removeItemAtPath:absolutePath error:&error]) {
        DDLogInfo(@"Error removing media files:%@", error);
    }
    NSString *absoluteThumbnailPath = self.absoluteThumbnailLocalURL.path;
    if ([fileManager fileExistsAtPath:absoluteThumbnailPath] &&
        ![fileManager removeItemAtPath:absoluteThumbnailPath error:&error]) {
        DDLogInfo(@"Error removing media files:%@", error);
    }
    [super prepareForDeletion];
}

- (BOOL)hasRemote {
    return self.mediaID.intValue != 0;
}

- (void)setError:(NSError *)error
{
    if (error != nil) {
        // Cherry pick keys that support secure coding. NSErrors thrown from the OS can
        // contain types that don't adopt NSSecureCoding, leading to a Core Data exception and crash.
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: error.localizedDescription};
        error = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
    }

    [self willChangeValueForKey:@"error"];
    [self setPrimitiveValue:error forKey:@"error"];
    [self didChangeValueForKey:@"error"];
}

@end
