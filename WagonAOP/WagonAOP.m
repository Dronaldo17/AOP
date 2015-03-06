//
//  WagonAOP.m
//  JoinShow
//
//  Created by Heaven on 14-10-17.
//  Copyright (c) 2014年 Heaven. All rights reserved.
//

#import "WagonAOP.h"
#import <objc/runtime.h>
#import <objc/message.h>

#undef	DEF_SINGLETON
#define DEF_SINGLETON( __class ) \
+ (__class *)sharedInstance \
{ \
static dispatch_once_t once; \
static __class * __singleton__; \
dispatch_once( &once, ^{ __singleton__ = [[self alloc] init]; } ); \
return __singleton__; \
}

typedef enum {
    WagonAOPAspectInspectorTypeBefore  = 0,
    WagonAOPAspectInspectorTypeInstead = 1,
    WagonAOPAspectInspectorTypeAfter   = 2
}WagonAOPAspectInspectorType;

static NSString *const WagonAOPAspectCurrentObjectKey = @"WagonAOPAspectCurrentObjectKey";

#define Wagon_Queue_Name "com.wagon.aopQueue"

@interface WagonAOP ()

@property (nonatomic, strong) dispatch_queue_t synchronizerQueue;
@property (nonatomic, copy) WagonAOP_block methodInvoker;

@property (nonatomic, strong) NSMutableDictionary *allInterceptors;

@end


@implementation WagonAOP


DEF_SINGLETON(WagonAOP);

- (instancetype)init
{
    self = [super init];
    if (self) {
        _allInterceptors   = [[NSMutableDictionary alloc] init];
        _synchronizerQueue = dispatch_queue_create(Wagon_Queue_Name, DISPATCH_QUEUE_SERIAL);
        _methodInvoker     = ^(NSInvocation *invocation) {
            [invocation invoke];
        };
        
    }
    return self;
}

- (NSString *)registerClass:(Class)aClass withSelector:(SEL)aSelector type:(WagonAOPAspectInspectorType)type usingBlock:(WagonAOP_block)block {
    NSParameterAssert(aClass);
    NSParameterAssert(aSelector);
    NSParameterAssert(block);
    
    SEL aSelectorNew = [self extendedSelectorWithClass:aClass selector:aSelector];
    
    // Hook a new method
    if (![self respondsToSelector:aSelectorNew])
    {
        Method method = class_getInstanceMethod(aClass, aSelector);
        
        // 给 aop 加新的处理方法 指向 类a 的方法
        class_addMethod([self class], aSelectorNew, method_getImplementation(method), method_getTypeEncoding(method));
        
        // 把类a的原本的方法aSelector的实现指针置为空
        [self interceptMethodWithClass:aClass selector:aSelector];
        
        SEL fSel     = @selector(forwardingTargetForSelector:);
        SEL fSelBase = @selector(baseClassForwardingTargetForSelector:);
        SEL fSelNew  = [self extendedSelectorWithClass:aClass selector:fSel];
        
        Method fMetod     = class_getInstanceMethod(aClass, fSel);
        Method fMetodBase = class_getInstanceMethod([self class], fSelBase);
        
        // 给 aop 添加一个方法 指向 类a的 forwardingTargetForSelector
        class_addMethod([self class], fSelNew, method_getImplementation(fMetod), method_getTypeEncoding(fMetod));
        
        // 把 类a 的 forwardingTargetForSelector 指向 aop 的basef 方法
        class_replaceMethod(aClass, fSel, method_getImplementation(fMetodBase), method_getTypeEncoding(fMetodBase));
        
        // 添加默认的方法调用块
        // Add the default method invoker block
        dispatch_sync(_synchronizerQueue, ^{
            [self saveInterceptorBlock:_methodInvoker withClass:aClass selector:aSelector type:WagonAOPAspectInspectorTypeInstead];
        });
    }
    
    // 存储要调用的块
    __block NSString *identifier;
    dispatch_sync(_synchronizerQueue, ^{
        identifier = [self saveInterceptorBlock:block withClass:aClass selector:aSelector type:type];
    });
    
    return identifier;
}

+ (NSString *)interceptClass:(Class)aClass beforeExecutingSelector:(SEL)selector usingBlock:(WagonAOP_block)block
{
    return [[self sharedInstance] interceptClass:aClass beforeExecutingSelector:selector usingBlock:block];
}
+ (NSString *)interceptClass:(Class)aClass afterExecutingSelector:(SEL)selector usingBlock:(WagonAOP_block)block
{
    return [[self sharedInstance] interceptClass:aClass afterExecutingSelector:selector usingBlock:block];
}
+ (NSString *)interceptClass:(Class)aClass insteadExecutingSelector:(SEL)selector usingBlock:(WagonAOP_block)block
{
    return [[self sharedInstance] interceptClass:aClass insteadExecutingSelector:selector usingBlock:block];
}

+ (void)removeInterceptorWithIdentifier:(NSString *)identifier
{
    return [[self sharedInstance] removeInterceptorWithIdentifier:identifier];
}

- (NSString *)interceptClass:(Class)aClass beforeExecutingSelector:(SEL)selector usingBlock:(WagonAOP_block)block
{
    return [self registerClass:aClass withSelector:selector type:WagonAOPAspectInspectorTypeBefore usingBlock:block];
}

- (NSString *)interceptClass:(Class)aClass afterExecutingSelector:(SEL)selector usingBlock:(WagonAOP_block)block
{
    return [self registerClass:aClass withSelector:selector type:WagonAOPAspectInspectorTypeAfter usingBlock:block];
}

- (NSString *)interceptClass:(Class)aClass insteadExecutingSelector:(SEL)selector usingBlock:(WagonAOP_block)block
{
    return [self registerClass:aClass withSelector:selector type:WagonAOPAspectInspectorTypeInstead usingBlock:block];
}

#pragma mark - Helper methods
- (NSString *)keyWithClass:(Class)aClass selector:(SEL)selector
{
    return [NSString stringWithFormat:@"__%@_%@", NSStringFromClass(aClass), NSStringFromSelector(selector)];
}

- (SEL)extendedSelectorWithClass:(Class)aClass selector:(SEL)selector
{
    return NSSelectorFromString([self keyWithClass:aClass selector:selector]);
}

- (NSString *)identifierWithClass:(Class)aClass selector:(SEL)aSelector dictionary:(NSDictionary *)dictionary
{
    return [NSString stringWithFormat:@"%@ | %@ | %p", NSStringFromClass(aClass), NSStringFromSelector(aSelector), dictionary];
}

- (void)setCurrentObject:(id)anObject
{
    [[NSThread currentThread] threadDictionary][WagonAOPAspectCurrentObjectKey] =  anObject;
}

- (id)currentObject
{
    return [[NSThread currentThread] threadDictionary][WagonAOPAspectCurrentObjectKey];
}
- (Class)currentClass
{
    return [[[NSThread currentThread] threadDictionary][WagonAOPAspectCurrentObjectKey] class];
}
#pragma mark - Interceptor registration
// 恢复被拦截的方法的imp
- (void)restoreOriginalMethodWithClass:(Class)aClass selector:(SEL)aSelector
{
    Method method      = class_getInstanceMethod(aClass, aSelector);
    IMP implementation = class_getMethodImplementation([self class], [self extendedSelectorWithClass:aClass selector:aSelector]);
    method_setImplementation(method, implementation);
}

// 把某方法的imp置空, 这样就走转发流程
- (void)interceptMethodWithClass:(Class)aClass selector:(SEL)aSelector
{
    Method method      = class_getInstanceMethod(aClass, aSelector);
    IMP implementation = (IMP)_objc_msgForward;
    method_setImplementation(method, implementation);
}

- (NSString *)saveInterceptorBlock:(WagonAOP_block)block withClass:(Class)aClass selector:(SEL)aSelector type:(WagonAOPAspectInspectorType)type
{
    NSString *key = [self keyWithClass:aClass selector:aSelector];
    
    NSMutableDictionary *interceptorTypeDic = _allInterceptors[key];
    
    if (interceptorTypeDic == nil)
    {
        interceptorTypeDic    = [[NSMutableDictionary alloc] init];
        _allInterceptors[key] = interceptorTypeDic;
    }
    
    NSMutableArray *interceptorArray = interceptorTypeDic[@(type)];
    
    if (interceptorArray == nil)
    {
        interceptorArray            = [[NSMutableArray alloc] init];
        interceptorTypeDic[@(type)] = interceptorArray;
    }
    
    NSDictionary *interceptor = @{[NSDate date] : block};
    
    if (type == WagonAOPAspectInspectorTypeInstead && interceptorArray.count == 1)
    {
        if ([[[interceptorArray lastObject] allValues] lastObject] == (id)_methodInvoker)
        {
            [interceptorArray removeLastObject];
        }
    }
    
    [interceptorArray addObject:interceptor];
    
    return [self identifierWithClass:aClass selector:aSelector dictionary:interceptor];
}

- (void)deregisterMethodWithClass:(Class)aClass selector:(SEL)aSelector
{
    [self restoreOriginalMethodWithClass:aClass selector:aSelector];
    [_allInterceptors removeObjectForKey:[self keyWithClass:aClass selector:aSelector]];
}

- (void)removeInterceptorWithIdentifier:(NSString *)identifier
{
    NSArray *components = [identifier componentsSeparatedByString:@" | "];
    Class aClass = NSClassFromString(components[0]);
    SEL selector = NSSelectorFromString(components[1]);
    
    dispatch_sync(_synchronizerQueue, ^{
        for (NSDictionary *interceptorTypeDic in [_allInterceptors allValues])
        {
            NSInteger interceptorCount = 0;
            
            for (int i = 0; i < 3; i++)
            {
                NSMutableArray *interceptorArray = interceptorTypeDic[@(i)];
                
                for (NSDictionary *dic in [NSArray arrayWithArray:interceptorArray])
                {
                    
                    if ([[self identifierWithClass:aClass selector:selector dictionary:dic] isEqualToString:identifier])
                    {
                        [interceptorArray removeObject:dic];
                        if (i == WagonAOPAspectInspectorTypeInstead && interceptorArray.count == 0)
                        {
                            [self saveInterceptorBlock:_methodInvoker withClass:aClass selector:selector type:i];
                        }
                    }
                }
                
                interceptorCount += interceptorArray.count;
            }
            
            if (interceptorCount == 1 && [[[interceptorTypeDic[@(WagonAOPAspectInspectorTypeInstead)] lastObject] allValues] lastObject] == (id)_methodInvoker)
            {
                [self deregisterMethodWithClass:aClass selector:selector];
            }
        }
    });
}
- (void)executeInterceptorsWithClass:(Class)aClass selector:(SEL)aSelector invocation:(NSInvocation *)anInvocation {
    NSString *key = [self keyWithClass:aClass selector:aSelector];
    __block NSMutableDictionary *interceptorTypeDic;
    
    dispatch_sync(_synchronizerQueue, ^{
        interceptorTypeDic = _allInterceptors[key];
    });
    
    [self restoreOriginalMethodWithClass:aClass selector:aSelector];
    
    for (int i = 0; i < 3; i++)
    {
        __block NSArray *interceptorArray;
        
        dispatch_sync(_synchronizerQueue, ^{
            interceptorArray = [NSArray arrayWithArray:interceptorTypeDic[@(i)]];
        });
        
        for (NSDictionary *interceptor in interceptorArray)
        {
            WagonAOP_block block = [[interceptor allValues] lastObject];
            block(anInvocation);
        }
    }
    
    [self interceptMethodWithClass:aClass selector:aSelector];
}

// 快速消息转发, 若该方法返回值对象非nil或非self，则向该返回对象重新发送消息。
- (id)baseClassForwardingTargetForSelector:(SEL)aSelector
{
    if (![self respondsToSelector:aSelector])
    {
        SEL fSelNew = [[WagonAOP sharedInstance] extendedSelectorWithClass:[self class] selector:@selector(forwardingTargetForSelector:)];
         return objc_msgSend([WagonAOP sharedInstance], fSelNew);
//        return [[WagonAOP sharedInstance] performSelector:fSelNew];
    }
    
    [[WagonAOP sharedInstance] setCurrentObject:self];
    
    return [WagonAOP sharedInstance];
}

// 标准消息转发 1
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [[self currentClass] instanceMethodSignatureForSelector:aSelector];
}
// 标准消息转发 2
- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    anInvocation.target = [self currentObject];
    [self executeInterceptorsWithClass:[self currentClass] selector:anInvocation.selector invocation:anInvocation];
}
@end
