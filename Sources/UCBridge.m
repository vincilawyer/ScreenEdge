#import "UCBridge.h"
#import <objc/runtime.h>
#import <dlfcn.h>

@protocol SEUniversalControlReadOnly
- (void)xpcGetEdgesWithCompletion:(void (^)(NSArray * _Nullable, NSError * _Nullable))completion;
@end

/// Apple's secure wrapper encodes its value as a property list / JSON payload.
/// Capture the encoding through NSCoder rather than reading Swift object memory.
@interface SEEdgeValueCoder : NSCoder
@property(nonatomic, strong) id payload;
@end
@implementation SEEdgeValueCoder
- (BOOL)allowsKeyedCoding { return YES; }
- (void)encodeObject:(id)object forKey:(NSString *)key {
    if ([key isEqualToString:@"UniversalControlEdgeRegion"]) self.payload = object;
}
@end

@interface SEEdgeQuery : NSObject
@property(nonatomic, strong) NSXPCConnection *connection;
@property(nonatomic, copy) void (^completion)(NSArray<NSDictionary *> *, NSString *);
@property(nonatomic) BOOL finished;
- (void)start;
@end

@implementation SEEdgeQuery
- (void)finish:(NSArray<NSDictionary *> *)edges error:(NSString *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.finished) return;
        self.finished = YES;
        void (^callback)(NSArray<NSDictionary *> *, NSString *) = self.completion;
        self.completion = nil;
        [self.connection invalidate];
        self.connection = nil;
        if (callback) callback(edges, error);
    });
}
- (void)start {
    static void *framework;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        framework = dlopen("/System/Library/PrivateFrameworks/UniversalControl.framework/Versions/A/UniversalControl", RTLD_LAZY | RTLD_LOCAL);
    });
    Protocol *protocol = objc_getProtocol("UniversalControl.UniversalControlXPCBasicInterface");
    Class edgeClass = NSClassFromString(@"UniversalControlXPCEdgeRegion");
    if (!framework || !protocol || !edgeClass) {
        [self finish:nil error:@"当前系统未提供兼容的通用控制边缘接口。"];
        return;
    }
    @try {
        SEL selector = @selector(xpcGetEdgesWithCompletion:);
        NSXPCInterface *interface = [NSXPCInterface interfaceWithProtocol:protocol];
        NSMutableSet *classes = [[interface classesForSelector:selector argumentIndex:0 ofReply:YES] mutableCopy];
        [classes addObject:edgeClass];
        [interface setClasses:classes forSelector:selector argumentIndex:0 ofReply:YES];
        self.connection = [[NSXPCConnection alloc] initWithMachServiceName:@"com.apple.ensemble" options:0];
        self.connection.remoteObjectInterface = interface;
        __weak SEEdgeQuery *weakSelf = self;
        self.connection.interruptionHandler = ^{ [weakSelf finish:nil error:@"通用控制服务暂时中断，稍后自动重试。 "]; };
        self.connection.invalidationHandler = ^{ [weakSelf finish:nil error:@"暂时无法读取通用控制通道，稍后自动重试。 "]; };
        [self.connection resume];
        id<SEUniversalControlReadOnly> proxy = [self.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
            [weakSelf finish:nil error:@"暂时无法读取通用控制通道，稍后自动重试。"];
        }];
        [proxy xpcGetEdgesWithCompletion:^(NSArray *edges, NSError *error) {
            SEEdgeQuery *query = weakSelf;
            if (!query) return;
            @try {
                if (error || ![edges isKindOfClass:NSArray.class] || edges.count > 256) {
                    [query finish:nil error:@"系统暂未返回有效的通用控制通道。"];
                    return;
                }
                NSMutableArray<NSDictionary *> *values = [NSMutableArray array];
                for (id edge in edges) {
                    if (![edge isKindOfClass:edgeClass] || ![edge respondsToSelector:@selector(encodeWithCoder:)]) {
                        [query finish:nil error:@"系统的通用控制数据格式已变化。"];
                        return;
                    }
                    SEEdgeValueCoder *coder = [SEEdgeValueCoder new];
                    [edge encodeWithCoder:coder];
                    id value = coder.payload;
                    if ([value isKindOfClass:NSData.class] && [value length] <= 1024 * 1024) {
                        id parsed = [NSPropertyListSerialization propertyListWithData:value options:NSPropertyListImmutable format:nil error:nil];
                        if (!parsed) parsed = [NSJSONSerialization JSONObjectWithData:value options:0 error:nil];
                        value = parsed;
                    }
                    if (![value isKindOfClass:NSDictionary.class]) {
                        [query finish:nil error:@"暂时无法解析系统的通用控制通道。"];
                        return;
                    }
                    [values addObject:value];
                }
                [query finish:values error:nil];
            } @catch (NSException *exception) {
                [query finish:nil error:@"系统的通用控制数据格式暂不兼容。"];
            }
        }];
    } @catch (NSException *exception) {
        [self finish:nil error:@"当前系统的通用控制接口暂不兼容。"];
    }
    // Retain the query only for this bounded request; late callbacks are ignored.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self finish:nil error:@"读取通用控制通道超时，稍后自动重试。"];
    });
}
@end

void SEReadUniversalControlEdges(void (^completion)(NSArray<NSDictionary *> *, NSString *)) {
    SEEdgeQuery *query = [SEEdgeQuery new];
    query.completion = completion;
    [query start];
}
