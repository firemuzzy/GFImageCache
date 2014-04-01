//
//  GFImageCache.h
//  GitFlub
//
//  Created by Michael Charkin on 2/18/14.
//
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa.h>

@interface GFImageCache : NSObject

+ (GFImageCache *)sharedInstance;

- (void)setLogging:(BOOL)loggingEnabled;
- (RACSignal *)imageForUrl:(NSString *)url;

@end
