///
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
    UIButton * button = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    [button setBackgroundColor:[UIColor blackColor]];
    [button setTitle:@"AOPTest" forState:UIControlStateNormal];
    [button setTitle:@"AOPTest" forState:UIControlStateHighlighted];
    
    [button addTarget:self action:@selector(aopTest:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
}
-(void)aopTest:(id)sender
{
    __block NSString * before;
    __block NSString * after;
    before  = [WagonAOP interceptClass:[AOPTest class] beforeExecutingSelector:@selector(sumA:andB:)   usingBlock:^(NSInvocation *invocation) {
        int a = 3;
        int b = 4;
        
        //        [invocation setArgument: &myString atIndex: 2];为什么index从2开始 ，原因为：0 1 两个参数已经被target 和selector占用。
        
        [invocation setArgument:&a atIndex:2];
        [invocation setArgument:&b atIndex:3];
        
        NSLog(@"berore fun. a = %d, b = %d", a , b);
    }];
    NSLog(@"before is %@",before);
    
    after = [WagonAOP interceptClass:[AOPTest class] afterExecutingSelector:@selector(sumA:andB:) usingBlock:^(NSInvocation *invocation) {
        int c;
        
        [invocation getReturnValue:&c];
        
        NSLog(@"after fun. sum = %d",c);
#warning 这两个取消 不知道放到哪里合适了 现在是个Bug 请大家帮忙看看  现在如果这两个都放到这 第一次OK 第二次 就不对了  
        [WagonAOP removeInterceptorWithIdentifier:before];
        [WagonAOP removeInterceptorWithIdentifier:after];
    }];
    NSLog(@"after is %@",after);
    
    AOPTest * test = [AOPTest alloc];
    [test sumA:1 andB:2];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

