//
//  AhaBlurryView.m
//  AhaBlurryView
//
//  Created by haiwei on 3/31/16.
//  Copyright © 2016 vvlvv. All rights reserved.
//

#import "AhaBlurryView.h"
#import <Accelerate/Accelerate.h>

@interface AhaBlurryManager : NSObject

@property (nonatomic, strong) AhaBlurryView * blurryView;

@end

@implementation AhaBlurryManager


+ (AhaBlurryManager *)sharedAhaBlurryManager {
    static AhaBlurryManager *sharedAhaBlurryManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedAhaBlurryManager = [[self alloc] init];
    });
    return sharedAhaBlurryManager;
}

+ (void)load {
    
    [super load];
    [AhaBlurryManager sharedAhaBlurryManager];
}


- (id)init {
    
    if (self = [super init]) {
        [self addNotification];
    }
    return self;
}

- (void)addNotification {
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)applicationDidEnterBackground:(NSNotification *)noti {
    
    //添加
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        if (window.windowLevel == UIWindowLevelNormal) {
            self.blurryView = [[AhaBlurryView alloc] initWithFrame:window.frame];
            [window addSubview:self.blurryView];
        }
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)noti {
    //移除
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        if (window.windowLevel == UIWindowLevelNormal) {
            [UIView animateWithDuration:0.4
                             animations:^{
                                 self.blurryView.alpha = 0.0f;
                             } completion:^(BOOL finished) {
                                 [self.blurryView removeFromSuperview];
                                 self.blurryView = nil;
                             }];
        }
    }
}

@end



@implementation AhaBlurryView


- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        
        UIImage *image = [UIImage imageWithData:UIImageJPEGRepresentation([self getCurrentImage], 1.0)];
        UIImage *blurryImage =  [self blurryImage:image withBlurLevel:0.1];
        UIImageView *bgView = [[UIImageView alloc] initWithFrame:frame];
        bgView.image = blurryImage;
        [self addSubview:bgView];
    }
    return self;
}

- (UIImage *)getCurrentImage {
    
    UIWindow *window = [[UIApplication sharedApplication].delegate window];
    UIGraphicsBeginImageContext(window.rootViewController.view.bounds.size);
    [window.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (UIImage *)blurryImage:(UIImage *)image withBlurLevel:(CGFloat)blur {
    
    if (blur < 0.f || blur > 1.f) {
        blur = 0.5f;
    }
    
    int boxSize = (int)(blur * 100);
    boxSize = boxSize - (boxSize % 2) + 1;
    
    CGImageRef img = image.CGImage;
    
    vImage_Buffer inBuffer, outBuffer;
    vImage_Error error;
    
    void *pixelBuffer;
    
    CGDataProviderRef inProvider = CGImageGetDataProvider(img);
    CFDataRef inBitmapData = CGDataProviderCopyData(inProvider);
    
    inBuffer.width = CGImageGetWidth(img);
    inBuffer.height = CGImageGetHeight(img);
    inBuffer.rowBytes = CGImageGetBytesPerRow(img);
    
    inBuffer.data = (void*)CFDataGetBytePtr(inBitmapData);
    
    pixelBuffer = malloc(CGImageGetBytesPerRow(img) *
                         CGImageGetHeight(img));
    
    if(pixelBuffer == NULL) {
        NSLog(@"No pixelbuffer");
    }
    
    outBuffer.data = pixelBuffer;
    outBuffer.width = CGImageGetWidth(img);
    outBuffer.height = CGImageGetHeight(img);
    outBuffer.rowBytes = CGImageGetBytesPerRow(img);
    
    error = vImageBoxConvolve_ARGB8888(&inBuffer,
                                       &outBuffer,
                                       NULL,
                                       0,
                                       0,
                                       boxSize,
                                       boxSize,
                                       NULL,
                                       kvImageEdgeExtend);
    
    
    if (error) {
        NSLog(@"error from convolution %ld", error);
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(
                                             outBuffer.data,
                                             outBuffer.width,
                                             outBuffer.height,
                                             8,
                                             outBuffer.rowBytes,
                                             colorSpace,
                                             kCGImageAlphaNoneSkipLast);
    CGImageRef imageRef = CGBitmapContextCreateImage (ctx);
    UIImage *returnImage = [UIImage imageWithCGImage:imageRef];
    
    //clean up
    CGImageRelease(imageRef);
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    free(pixelBuffer);
    CFRelease(inBitmapData);
    
    return returnImage;
}

@end