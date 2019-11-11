//
//  QINiuObjectStoreManager.m
//  CocoaAsyncSocket
//
//  Created by Khazan on 2019/8/15.
//

#import "QINiuObjectStoreManager.h"
#import <CommonCrypto/CommonHMAC.h>

#import "KZURLRequestSerialization.h"

@implementation QINiuObjectStoreManager


+ (void)uploadFileWithData:(NSData *)data
                      host:(NSString *)host
                    bucket:(NSString *)bucket
                  fileName:(NSString *)fileName
                 accessKey:(NSString *)accessKey
                 secretKey:(NSString *)secretKey
                   success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                   failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    
    if (data == nil || host == nil || bucket == nil) {
        return;
    }
    
    NSDictionary *putPolicy = [self putPolicyWithBucket:bucket filename:fileName];
    NSString *encodedPutPolicy = [self urlsafe_base64_encodeWithPutPolicy:putPolicy];
    NSData *hmac = [self hmac_sha1WithEncodedPutPolicy:encodedPutPolicy secretKey:secretKey];
    NSString *encodedSign = [self urlsafe_base64_encodeWithHmac:hmac];
    NSString *uploadToken = [self uploadTokenWithAccessKey:accessKey encodedSign:encodedSign encodedPutPolicy:encodedPutPolicy];

    NSDictionary *params = @{@"token": uploadToken, @"key": fileName};
    
    [self uploadFileWithURL:host parameters:params constructingBodyWithBlock:^(id<KZMultipartFormData> formData) {
        [formData appendPartWithFileData:data name:@"file" fileName:fileName mimeType:@"application/octet-stream"];
    } success:success failure:failure];
}


+ (NSDictionary *)putPolicyWithBucket:(NSString *)bucket filename:(NSString *)filename {
    NSString *scope = [NSString stringWithFormat:@"%@:%@", bucket, filename];
    NSNumber *deadline = [NSNumber numberWithUnsignedInteger:[self deadlineTime]];

    NSDictionary *putPolicy = @{
                                @"scope": scope,
                                @"deadline": deadline
                                };
    
    NSLog(@"putPolicy:%@", putPolicy);
    return putPolicy;
}


+ (NSString *)urlsafe_base64_encodeWithPutPolicy:(NSDictionary *)putPolicy {
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:putPolicy options:NSJSONWritingPrettyPrinted error:&error];
    if (error) {
        NSLog(@"");
    }
    NSString *base64String = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    // url safe
    NSString *urlsafe_base64String = [base64String stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    urlsafe_base64String = [urlsafe_base64String stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    
    NSLog(@"urlsafe_base64_encodeWithPutPolicy:%@", urlsafe_base64String);
    return urlsafe_base64String;
}

+ (NSData *)hmac_sha1WithEncodedPutPolicy:(NSString *)encodedPutPolicy secretKey:(NSString *)secretKey {
    const char *cKey  = [secretKey cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cData = [encodedPutPolicy cStringUsingEncoding:NSUTF8StringEncoding];
    
    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA1, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    
    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
    return HMAC;
}

+ (NSString *)urlsafe_base64_encodeWithHmac:(NSData *)hmac {
    NSString *base64String = [hmac base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    // url safe
    NSString *urlsafe_base64String = [base64String stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    urlsafe_base64String = [urlsafe_base64String stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    
    NSLog(@"urlsafe_base64_encodeWithSign:%@", urlsafe_base64String);
    return urlsafe_base64String;
}

+ (NSString *)uploadTokenWithAccessKey:(NSString *)AccessKey encodedSign:(NSString *)encodedSign encodedPutPolicy:(NSString *)encodedPutPolicy {
    NSString *uploadToken = [NSString stringWithFormat:@"%@:%@:%@", AccessKey, encodedSign, encodedPutPolicy];
    
    NSLog(@"uploadToken:%@", uploadToken);
    return uploadToken;
}




+ (void)uploadFileWithURL:(NSString *)url
               parameters:(NSDictionary *)parameters
constructingBodyWithBlock:(void (^)(id <KZMultipartFormData> formData))block
                  success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                  failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure
{
    NSError *serializationError = nil;

    NSMutableURLRequest *request = [[KZHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST" URLString:url parameters:parameters constructingBodyWithBlock:block error:&serializationError];
    
    if (serializationError && failure) {
        failure(nil, serializationError);
        return;
    }
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    [session finishTasksAndInvalidate];

    __block NSURLSessionDataTask *task = [session uploadTaskWithRequest:request fromData:nil completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error == nil && success) {
            success(task, data);
        } else if (error && failure) {
            failure(task, serializationError);
        } else {
            
        }
    }];
    
    [task resume];
}


+ (NSUInteger)deadlineTime {
    NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
    return time + 3600;
}



@end


