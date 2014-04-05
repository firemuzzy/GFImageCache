//
//  GFImageCache.h
//  GFImageCache
//
//  Created by Michael Charkin on 2/25/14.
//  Copyright (c) 2014 GitFlub. All rights reserved.
//

#import "GFImageCache.h"
#import <ReactiveCocoa.h>

NSString * const GFImageCacheErrorDomain = @"GFImageCacheErrorDomain";
const NSInteger GFImageCacheMiss = 1001;


@interface GFImageContainer : NSObject

@property (nonatomic, strong, readonly) UIImage *image;
@property (nonatomic, strong, readonly) NSDate *fetchedOn;

- (instancetype)initWithImage:(UIImage *)image;

@end

@implementation GFImageContainer

- (instancetype)initWithImage:(UIImage *)image {
    if(self = [super init]) {
        _image = image;
        _fetchedOn = [NSDate date];
    }
    return self;
}

@end

@interface GFImageCache ()

@property (nonatomic, strong, readonly) NSCache *imgCache;
@property (nonatomic, strong, readonly) NSCache *signalCache;

@property (atomic, assign) BOOL loggingEnabled;

@end

@implementation GFImageCache

static GFImageCache *sharedInstance = nil;
+ (GFImageCache *)sharedInstance {
    if (nil != sharedInstance) {
        return sharedInstance;
    }
    
    static dispatch_once_t pred;        // Lock
    dispatch_once(&pred, ^{             // This code is called at most once per app
        sharedInstance = [[GFImageCache alloc] init];
    });
    
    return sharedInstance;
}

- (void)setLogging:(BOOL)loggingEnabled {
    self.loggingEnabled = loggingEnabled;
}

- (GFImageCache *) init {
    if(self = [super init]) {
        _imgCache = [[NSCache alloc] init];
        _signalCache = [[NSCache alloc] init];
    }
    return self;
}

- (RACSignal *)_fromSignalNSCacheForUrl:(NSString *)url {
    RACSignal *foundSignal = [self.signalCache objectForKey:url];
    if(foundSignal) {
        [self log:[NSString stringWithFormat:@"Fetched url %@ from signal cahce", url]];
        return foundSignal;
    }
    else return nil;
}
- (GFImageContainer *)_fromImageNSCacheForUrl:(NSString *)url {
    GFImageContainer *container = [self.imgCache objectForKey:url];
    if(container) {
        [self log:[NSString stringWithFormat:@"Fetched url %@ from image cache", url]];
    }
    
    return container;
}

- (RACSignal *)imageForUrl:(NSString *)url {
    if(url == nil) return [RACSignal return:nil];
    
    GFImageContainer *found = [self _fromImageNSCacheForUrl:url];
    if(found) { return [RACSignal return:found.image]; }
    
    RACSignal *foundSignal = [self _fromSignalNSCacheForUrl:url];
    if(foundSignal) { return foundSignal; }
    
    @synchronized(self) {
        // double check because of synchronization
        GFImageContainer *found = [self _fromImageNSCacheForUrl:url];
        if(found) { return [RACSignal return:found.image]; }
        
        RACSignal *foundSignal = [self _fromSignalNSCacheForUrl:url];
        if(foundSignal) { return foundSignal; }
        
        
        RACSignal *sig = [[self downloadImageFromURL:url] replayLazily];
        [_signalCache setObject:sig forKey:url];
        
        __weak GFImageCache *weakSelf = self;
        [sig subscribeNext:^(UIImage *downloadedImage) {
            GFImageContainer *container = [[GFImageContainer alloc] initWithImage:downloadedImage];
            [weakSelf.imgCache setObject:container forKey:url];
            [weakSelf.signalCache removeObjectForKey:url];
        } error:^(NSError *error) {
            [weakSelf.signalCache removeObjectForKey:url];
        }];
        return sig;
    }
}

-(RACSignal *)downloadImageFromURL:(NSString *)url {
    NSParameterAssert(url != nil);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    // another configuration option is backgroundSessionConfiguration (multitasking API required though)
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    
    // create the session without specifying a queue to run completion handler on (thus, not main queue)
    // we also don't specify a delegate (since completion handler is all we need)
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    
    return [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [self log:[NSString stringWithFormat:@"Downloading image from url %@", url]];
        
        NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:request
                                                        completionHandler:^(NSURL *localfile, NSURLResponse *response, NSError *error) {
                                                            // this handler is not executing on the main queue, so we can't do UI directly here
                                                            if (!error) {
                                                                [self logSuccessfromUrl:url withFileURL:localfile];
                                                                UIImage *image = (localfile == nil) ? nil : [UIImage imageWithData:[NSData dataWithContentsOfURL:localfile]];
                                                                [subscriber sendNext:image];
                                                                [subscriber sendCompleted];
                                                            } else {
                                                                [self logError:error fromUrl:url];
                                                                [subscriber sendError:error];
                                                            }
                                                        }];
        [task resume]; // don't forget that all NSURLSession tasks start out suspended!
        
        return [RACDisposable disposableWithBlock:^{
            [task cancel];
        }];
    }] replayLazily];
}

- (void)logError:(NSError *)error fromUrl:(NSString *)url {
    if(self.loggingEnabled) {
        NSLog(@"Failed to donwload image from %@ error:%@", url, error.localizedDescription);
    }
}

- (void)logSuccessfromUrl:(NSString *)url withFileURL:(NSURL *)localfileUrl {
    if(self.loggingEnabled) {
        NSLog(@"Donwloaded image from url:%@ sucesfully to %@", url, [localfileUrl absoluteString]);
    }
}

- (void)log:(NSString *)message {
    if(self.loggingEnabled) {
        NSLog(@"%@", message);
    }
}

+ (NSError *)chaosErrorFetchingIssues {
	NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: NSLocalizedString(@"Image cache miss.", @""),
                               NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Image cache miss.", @""),
                               };
    
	return [NSError errorWithDomain:GFImageCacheErrorDomain code:GFImageCacheMiss userInfo:userInfo];
}


@end
