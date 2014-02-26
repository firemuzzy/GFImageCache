//
//  GFImageCache.h
//  GFImageCache
//
//  Created by Michael Charkin on 2/25/14.
//  Copyright (c) 2014 GitFlub. All rights reserved.
//

#import "GFImageCache.h"
#import <ReactiveCocoa.h>
#import "AsyncImageDownloader.h"

NSString * const GFImageCacheErrorDomain = @"GFImageCacheErrorDomain";
const NSInteger GFImageCacheMiss = 1001;

@interface GFImageCache ()

@property (nonatomic, strong, readonly) NSCache *imgCache;
@property (nonatomic, strong, readonly) NSCache *signalCache;


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

- (GFImageCache *) init {
    if(self = [super init]) {
        _imgCache = [[NSCache alloc] init];
        _signalCache = [[NSCache alloc] init];
    }
    return self;
}

- (RACSignal *)imageForUrl:(NSString *)url {
    UIImage *found = [self.imgCache objectForKey:url];
    if(found) {
        return [RACSignal return:found];
    }
    
    RACSignal *foundSignal = [self.signalCache objectForKey:url];
    if(foundSignal) {
        return foundSignal;
    }
    
    @synchronized(self) {
        RACSignal *sig = [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
            [[[AsyncImageDownloader alloc] initWithMediaURL:url successBlock:^(UIImage *downloadedImage) {
                [self.imgCache setObject:downloadedImage forKey:url];
                [self.signalCache removeObjectForKey:url];
                
                [subscriber sendNext:downloadedImage];
                [subscriber sendCompleted];
            } failBlock:^(NSError *error) {
                [self.signalCache removeObjectForKey:url];
                
                [subscriber sendError:error];
            }] startDownload];
            
            return [RACDisposable disposableWithBlock:^{
                // do nothing
                // TODO: tweak the image async donlowder to get the connection
            }];
        }] replayLazily];
        [_signalCache setObject:sig forKey:url];
        return sig;
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
