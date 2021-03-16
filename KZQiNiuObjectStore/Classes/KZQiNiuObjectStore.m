//
//  KZQiNiuObjectStore.m
//  KZQiNiuObjectStore
//
//  Created by Khazan on 2021/3/15.
//

#import "KZQiNiuObjectStore.h"
#import "KZUploadViaFormData.h"
#import "KZUploadViaDataSplit.h"

@implementation KZQiNiuObjectStore

- (void)uploadWithData:(NSData *)data
              fileName:(NSString *)fileName
                  host:(NSString *)host
                bucket:(NSString *)bucket
             accessKey:(NSString *)accessKey
             secretKey:(NSString *)secretKey
                  kind:(NSUInteger)kind
               success:(void (^)(void))success
               failure:(void (^)(void))failure {
    
    if (kind == 0) {
        [[[KZUploadViaFormData alloc] init] uploadWithData:data fileName:fileName host:host bucket:bucket accessKey:accessKey secretKey:secretKey success:^{
            
        } failure:^{
            
        }];
    } else if (kind == 1) {
        [[[KZUploadViaDataSplit alloc] init] spliteDataAndUploadWithData:data fileName:fileName host:host bucket:bucket accessKey:accessKey secretKey:secretKey success:^{

        } failure:^{

        }];
    }
    
}

@end
