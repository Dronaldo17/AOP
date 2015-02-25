//
//  AOPTest.m
//  WagonAOP
//
//  Created by jingxuan.dou on 15/2/25.
//  Copyright (c) 2015年 jingxuan.dou. All rights reserved.
//

#import "AOPTest.h"

@implementation AOPTest
-(int)sumA:(int)a andB:(int)b
{
    NSLog(@"执行加函数");
    return a + b;
}
@end
