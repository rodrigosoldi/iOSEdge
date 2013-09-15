//
//  BEPBackgroundDownloadHandler.m
//  BepBop
//
//  Created by Cody A. Ray on 9/15/13.
//  Copyright (c) 2013 Bleeding Edge Press. All rights reserved.
//

#import "BEPBackgroundDownloadHandler.h"

#define BLog(formatString, ...) NSLog((@"%s " formatString), __PRETTY_FUNCTION__, ##__VA_ARGS__);

static NSString *DownloadURLString = @"http://lorempixel.com/400/200/animals/%@/";

@interface BEPBackgroundDownloadHandler ()

@property (nonatomic) NSMutableArray *images;
@property (nonatomic) NSMutableArray *downloadTasks;
@property (nonatomic) NSMutableSet *seenImages;
@property (nonatomic) NSDateFormatter *formatter;
@property (nonatomic) NSURLSession *session;

@end

@implementation BEPBackgroundDownloadHandler

+ (instancetype)sharedInstance {
    static BEPBackgroundDownloadHandler * __sharedInstance = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[BEPBackgroundDownloadHandler alloc] init];
    });

    return __sharedInstance;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.images = [NSMutableArray array];
        self.downloadTasks = [NSMutableArray array];
        self.seenImages = [NSMutableSet set];
        self.session = [self backgroundSession];
    }
    return self;
}

- (void)refresh
{
    [self refreshWithCompletionHandler:^(BOOL didReceiveNewImage, NSError *error) {}];
}

- (void)refreshWithCompletionHandler:(BEPRefreshCompletionHandler)completionHandler
{
    BLog();

    u_int32_t r = 1 + arc4random_uniform(10); // 1-10 inclusive
    NSString *key = [NSString stringWithFormat:@"%d", r];
    if ([self.seenImages containsObject:key]) {
        completionHandler(NO, nil);
        return;
    }

    [self.seenImages addObject:key];
    NSURL *downloadURL = [NSURL URLWithString:[NSString stringWithFormat:DownloadURLString, key]];
    BLog(@"URL %@", downloadURL);
	NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithURL:downloadURL];
    if (downloadTask == nil) {
        BLog(@"Got nil downloadTask. Why?");
        return completionHandler(NO, [NSError errorWithDomain:@"Got nil downloadTask" code:1 userInfo:nil]);
    }
    [downloadTask resume];

    // Add it to our data structures and the table
    [self.images insertObject:[NSNull null] atIndex:0];
    [self.downloadTasks insertObject:downloadTask atIndex:0];

    completionHandler(YES, nil);
}

- (NSURLSession *)backgroundSession
{
	static NSURLSession *session = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfiguration:@"com.bleedingedgepress.iosedge"];
		session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
	});
	return session;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.images.count; // same as self.downloadTasks.count
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }

    // Configure the cell...
    UIImage *image = [self.images objectAtIndex:indexPath.row];
    if (image != (id)[NSNull null]) {
        cell.imageView.image = image;
        cell.textLabel.text = [self.formatter stringFromDate:[NSDate date]];
    } else {
        cell.textLabel.text = @"Loading...";
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.images removeObjectAtIndex:indexPath.row];
        [self.downloadTasks removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    BLog();
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)downloadURL
{
    BLog();

    /*
     Copy the downloaded file from the downloadURL to the Documents directory of our app.
     */
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSArray *URLs = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentsDirectory = [URLs objectAtIndex:0];

    NSURL *originalURL = [[downloadTask originalRequest] URL];
    NSURL *destinationURL = [documentsDirectory URLByAppendingPathComponent:[originalURL lastPathComponent]];
    NSError *errorCopy;

    // For the purposes of testing, remove any esisting file at the destination.
    [fileManager removeItemAtURL:destinationURL error:NULL];
    BOOL success = [fileManager copyItemAtURL:downloadURL toURL:destinationURL error:&errorCopy];

    if (success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImage *image = [UIImage imageWithContentsOfFile:[destinationURL path]];
            for (int i = 0; i < [self.downloadTasks count]; i++) {
                if ([self.downloadTasks objectAtIndex:i] == downloadTask) {
                    [self.images replaceObjectAtIndex:i withObject:image];
                    // now reload this row with the image
//                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
//                    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                }
            }
        });
    } else {
        BLog(@"Error during the copy: %@", [errorCopy localizedDescription]);
    }
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    BLog();

    if (error == nil) {
        NSLog(@"Task: %@ completed successfully", task);
    } else {
        NSLog(@"Task: %@ completed with error: %@", task, [error localizedDescription]);
    }

    //    self.downloadTask = nil;
}

/*
 If an application has received an -application:handleEventsForBackgroundURLSession:completionHandler: message, the session delegate will receive this message to indicate that all messages previously enqueued for this session have been delivered. At this time it is safe to invoke the previously stored completion handler, or to begin any internal updates that will result in invoking the completion handler.
 */
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    BEPAppDelegate *appDelegate = (BEPAppDelegate *)[[UIApplication sharedApplication] delegate];
    if (appDelegate.backgroundSessionCompletionHandler) {
        void (^completionHandler)() = appDelegate.backgroundSessionCompletionHandler;
        appDelegate.backgroundSessionCompletionHandler = nil;
        completionHandler();
    }

    NSLog(@"All tasks are finished");
}

#pragma mark NSURLSessionDelegate

-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    BLog();
}

@end