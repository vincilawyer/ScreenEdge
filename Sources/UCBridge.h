#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Read only. The callback is delivered once on the main queue, including timeout and failure.
void SEReadUniversalControlEdges(void (^completion)(NSArray<NSDictionary *> * _Nullable edges, NSString * _Nullable error));
NS_ASSUME_NONNULL_END
