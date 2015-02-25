//
//  ViewController.m
//  WagonAOP
//
//  Created by jingxuan.dou on 15/2/25.
//  Copyright (c) 2015年 jingxuan.dou. All rights reserved.
//

#import "ViewController.h"
#import "WagonAOP.h"
#import "AOPTest.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSString * before = [WagonAOP interceptClass:[AOPTest class] beforeExecutingSelector:@selector(sumA:andB:)   usingBlock:^(NSInvocation *invocation) {
        int a = 3;
        int b = 4;

//        [invocation setArgument: &myString atIndex: 2];为什么index从2开始 ，原因为：0 1 两个参数已经被target 和selector占用。
        
        [invocation setArgument:&a atIndex:2];
        [invocation setArgument:&b atIndex:3];
        
        NSLog(@"berore fun. a = %d, b = %d", a , b);
    }];
    NSLog(@"before is %@",before);
    
    NSString * after = [WagonAOP interceptClass:[AOPTest class] afterExecutingSelector:@selector(sumA:andB:) usingBlock:^(NSInvocation *invocation) {
        int c;
        
        //        [invocation setArgument: &myString atIndex: 2];为什么index从2开始 ，原因为：0 1 两个参数已经被target 和selector占用。
        
//        [invocation getArgument:&a atIndex:2];
//        [invocation getArgument:&b atIndex:3];
        [invocation getReturnValue:&c];
        
        NSLog(@"after fun. sum = %d",c);
    }];
     NSLog(@"after is %@",after);
    
//    NSString * instead = [WagonAOP interceptClass:[AOPTest class] insteadExecutingSelector:@selector(sumA:andB:) usingBlock:^(NSInvocation *invocation) {
//        int c = 99999999;
//       
//        NSLog(@"instead fun.c is %d",c);
//        
//    }];
//     NSLog(@"instead is %@",instead);
    
    AOPTest * test = [AOPTest alloc];
    [test sumA:1 andB:2];
    
    [WagonAOP removeInterceptorWithIdentifier:before];
    [WagonAOP removeInterceptorWithIdentifier:after];
       
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
