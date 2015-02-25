//
// WagonAOP.h
//  Wagon
//
//  Created by jingxuan.dou on 15-2-25.
//  Copyright (c) 2015年 jingxuan.dou. All rights reserved.
// thanks AOP-for-Objective-C

#import <Foundation/Foundation.h>

typedef void(^WagonAOP_block)(NSInvocation *invocation);

@interface WagonAOP : NSObject

+ (NSString *)interceptClass:(Class)aClass beforeExecutingSelector:(SEL)selector usingBlock:(WagonAOP_block)block;
+ (NSString *)interceptClass:(Class)aClass afterExecutingSelector:(SEL)selector usingBlock:(WagonAOP_block)block;
+ (NSString *)interceptClass:(Class)aClass insteadExecutingSelector:(SEL)selector usingBlock:(WagonAOP_block)block;

+ (void)removeInterceptorWithIdentifier:(NSString *)identifier;

@end
