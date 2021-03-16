//
//  KZQiNiuObjectStore.h
//  KZQiNiuObjectStore
//
//  Created by Khazan on 2021/3/15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KZQiNiuObjectStore : NSObject

- (void)uploadWithData:(NSData *)data
              fileName:(NSString *)fileName
                  host:(NSString *)host
                bucket:(NSString *)bucket
             accessKey:(NSString *)accessKey
             secretKey:(NSString *)secretKey
                  kind:(NSUInteger)kind
               success:(void (^)(void))success
               failure:(void (^)(void))failure;

@end

NS_ASSUME_NONNULL_END
