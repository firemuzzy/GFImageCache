//
//  TestImageCacheAppTests.m
//  TestImageCacheAppTests
//
//  Created by Michael Charkin on 2/25/14.
//  Copyright (c) 2014 GitFlub. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <GFImageCache.h>

@interface TestImageCacheAppTests : XCTestCase

@end

@implementation TestImageCacheAppTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#define IMAGE_URL @"http://en.gravatar.com/userimage/61856994/12ed711637f791fc719d53198cde768a.png?size=200"

- (void)testImageDownloadingNilUrl
{
    GFImageCache *cache = [[GFImageCache alloc] init];
    [cache setLogging:YES];
    
    RACSignal *downloaded1 = [cache imageForUrl:nil];
    
    [downloaded1 subscribeNext:^(UIImage *image) {
        NSData *data = UIImagePNGRepresentation(image);
        XCTAssertNil(data, @"nil url does not provide nil data");
    }];
    
    [downloaded1 asynchronouslyWaitUntilCompleted:nil];
}

- (void)testDownloadingAUrlThatHasNoImage {
    GFImageCache *cache = [[GFImageCache alloc] init];
    [cache setLogging:YES];
    
    RACSignal *downloaded1 = [cache imageForUrl:nil];
    
    [downloaded1 subscribeNext:^(UIImage *image) {
        NSData *data = UIImagePNGRepresentation(image);
        XCTAssertNil(data, @"nil url does not provide nil data");
    }];
    
    [downloaded1 asynchronouslyWaitUntilCompleted:nil];
}

- (void)testImageDownloading
{
    UIImage *expectedImage = [UIImage imageNamed:@"testimage"];
    NSData *expectedData = UIImagePNGRepresentation(expectedImage);
    
    GFImageCache *cache = [[GFImageCache alloc] init];
    [cache setLogging:YES];
    
    RACSignal *downloaded1 = [cache imageForUrl:IMAGE_URL];
    RACSignal *downloaded2 = [cache imageForUrl:IMAGE_URL];
    RACSignal *downloaded3 = [cache imageForUrl:IMAGE_URL];

    [downloaded1 subscribeNext:^(UIImage *image) {
        NSData *data = UIImagePNGRepresentation(image);
        XCTAssertEqualObjects(data, expectedData, @"downloaded iamge does not match found image");
    }];
    
    [downloaded2 subscribeNext:^(UIImage *image) {
        NSData *data = UIImagePNGRepresentation(image);
        XCTAssertEqualObjects(data, expectedData, @"downloaded iamge does not match found image");
    }];
    
    [downloaded3 subscribeNext:^(UIImage *image) {
        NSData *data = UIImagePNGRepresentation(image);
        XCTAssertEqualObjects(data, expectedData, @"downloaded iamge does not match found image");
    }];
    
    [downloaded1 asynchronouslyWaitUntilCompleted:nil];
    [downloaded2 asynchronouslyWaitUntilCompleted:nil];
    [downloaded3 asynchronouslyWaitUntilCompleted:nil];
    
    XCTAssertEqualObjects(downloaded1, downloaded2, @"recieved different signals for thesame image download");
    XCTAssertEqualObjects(downloaded1, downloaded3, @"recieved different signals for thesame image download");
}

#define IMAGE_BAD_URL @"http://www.gitflub.io/nonexistantimage.png"

- (void)testInvalidImageDownloading
{
    GFImageCache *cache = [[GFImageCache alloc] init];
    [cache setLogging:YES];
    
    RACSignal *downloaded1 = [cache imageForUrl:IMAGE_BAD_URL];
    RACSignal *downloaded2 = [cache imageForUrl:IMAGE_BAD_URL];
    RACSignal *downloaded3 = [cache imageForUrl:IMAGE_BAD_URL];
    
    __block BOOL fail1Called = NO;
    __block BOOL fail2Called = NO;
    __block BOOL fail3Called = NO;
    
    [downloaded1 subscribeNext:^(UIImage *image) {
        XCTFail(@"image downloading should fail");
    } error:^(NSError *error) {
        fail1Called = YES;
    }];
    
    [downloaded2 subscribeNext:^(UIImage *image) {
        XCTFail(@"image downloading should fail");
    } error:^(NSError *error) {
        fail2Called = YES;
    }];
    
    [downloaded3 subscribeNext:^(UIImage *image) {
        XCTFail(@"image downloading should fail");
    } error:^(NSError *error) {
        fail3Called = YES;
    }];
    
    [downloaded1 asynchronouslyWaitUntilCompleted:nil];
    [downloaded2 asynchronouslyWaitUntilCompleted:nil];
    [downloaded3 asynchronouslyWaitUntilCompleted:nil];
    
    XCTAssertTrue(fail1Called, @"fail for donloading image 1 not called");
    XCTAssertTrue(fail2Called, @"fail for donloading image 2 not called");
    XCTAssertTrue(fail3Called, @"fail for donloading image 3 not called");
}

@end
