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

- (RACSignal *)imageForUrl:(NSString *)url {
    if(url == nil) return [RACSignal return:nil];
    
    UIImage *found = [self.imgCache objectForKey:url];
    if(found) {
        return [RACSignal return:found];
    }
    
    RACSignal *foundSignal = [self.signalCache objectForKey:url];
    if(foundSignal) {
        return foundSignal;
    }
    
    @synchronized(self) {
        RACSignal *sig = [[self downloadImageFromURL:url] replayLazily];
        [_signalCache setObject:sig forKey:url];

        [sig subscribeNext:^(UIImage *downloadedImage) {
            [self.imgCache setObject:downloadedImage forKey:url];
            [self.signalCache removeObjectForKey:url];
        } error:^(NSError *error) {
            [self.signalCache removeObjectForKey:url];
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
    
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:request
            completionHandler:^(NSURL *localfile, NSURLResponse *response, NSError *error) {
                // this handler is not executing on the main queue, so we can't do UI directly here
                if (!error) {
                    [self logSuccessfromUrl:url];
                    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:localfile]];
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
    }];
}

- (void)logError:(NSError *)error fromUrl:(NSString *)url {
    if(self.loggingEnabled) {
        NSLog(@"Failed to donwload image from %@ error:%@", url, error.localizedDescription);
    }
}

- (void)logSuccessfromUrl:(NSString *)url {
    if(self.loggingEnabled) {
        NSLog(@"Donwload image from url:%@", url);
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
