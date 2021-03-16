//
//  KZUploadViaDataSplit.m
//  KZQiNiuObjectStore
//
//  Created by Khazan on 2021/3/15.
//

#import "KZUploadViaDataSplit.h"
#import "KZUploadToken.h"
#import "KZQiNiuObjectStoreConstants.h"

@interface KZUploadViaDataSplit ()

@property (nonatomic, strong) NSURLSession *session;

@end

@implementation KZUploadViaDataSplit


# pragma mark - splite data and upload subdata
- (void)spliteDataAndUploadWithData:(NSData *)data
                           fileName:(NSString *)fileName
                               host:(NSString *)host
                             bucket:(NSString *)bucket
                          accessKey:(NSString *)accessKey
                          secretKey:(NSString *)secretKey
                            success:(void (^)(void))success
                            failure:(void (^)(void))failure {
    
    NSString *uploadToken = [KZUploadToken tokenWithBucket:bucket fileName:fileName accessKey:accessKey secretKey:secretKey];
    NSString *fileNameBase64 = [[fileName dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn];
    
    [self createUploadTaskWithHost:host
                            bucket:bucket
                         accessKey:accessKey
                         secretKey:secretKey
                       uploadToken:(NSString *)uploadToken
                          fileName:fileName
                    fileNameBase64:fileNameBase64
                           success:^(NSDictionary *responseObject) {
        
        NSString *uploadId = [responseObject objectForKey:@"uploadId"];
        
        [self splitData:data
         uploadWithHost:host
                 bucket:bucket
         fileNameBase64:fileNameBase64
               uploadId:uploadId
            uploadToken:uploadToken
                success: success
                failure:failure];
        
    }
                           failure:^(NSError *error) {
        failure ? failure() : nil;
    }];
}

- (void)createUploadTaskWithHost:(NSString *)host
                          bucket:(NSString *)bucket
                       accessKey:(NSString *)accessKey
                       secretKey:(NSString *)secretKey
                     uploadToken:(NSString *)uploadToken
                        fileName:(NSString *)fileName
                 fileNameBase64:(NSString *)fileNameBase64
                         success:(void (^)(NSDictionary *responseObject))success
                         failure:(void (^)(NSError *error))failure {
    
    NSString *url = [NSString stringWithFormat:@"%@/buckets/%@/objects/%@/uploads", @"https://up-z2.qiniup.com", bucket, fileNameBase64];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    NSDictionary *parameters = @{@"BucketName": bucket};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:nil];
    
    [request setValue:[NSString stringWithFormat:@"UpToken %@", uploadToken] forHTTPHeaderField:@"Authorization"];
    request.HTTPMethod = @"POST";
    
    KZLOG(@"allHTTPHeaderFields:%@", request.allHTTPHeaderFields);
    KZLOG(@"url: %@", request.URL);
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            KZLOG(@"upload failure :%@", error);
            failure ? failure(error) : nil;
        } else {
            NSError *jsonErr;
            NSDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&jsonErr];
            if (jsonErr) {
                failure ? failure(error) : nil;
            } else {
                KZLOG(@"upload success: %@", responseObject);
                success ? success(responseObject) : nil;
            }
        }
    }];
    
    [task resume];
}

- (void)splitData:(NSData *)data
   uploadWithHost:(NSString *)host
           bucket:(NSString *)bucket
  fileNameBase64:(NSString *)fileNameBase64
         uploadId:(NSString *)uploadId
      uploadToken:(NSString *)uploadToken
          success:(void (^)(void))success
          failure:(void (^)(void))failure {
    
    NSUInteger chunkSize = 1024 * 1024;
    NSUInteger number = data.length / chunkSize;
    
    NSMutableArray *uploadSuccess = [NSMutableArray arrayWithCapacity:0];
    dispatch_group_t group = dispatch_group_create();
    
    for (NSUInteger i = 0; i <= number; i++) {
        dispatch_group_enter(group);
        NSRange range = NSMakeRange(i * chunkSize, MIN(data.length - i * chunkSize, chunkSize));
        NSData *subData = [data subdataWithRange:range];
        [self uploadSubData:subData
                       host:host
                     bucket:bucket
            fileNameBase64:fileNameBase64
                      index:i
                   uploadId:uploadId
                uploadToken:uploadToken
                    success:^(NSDictionary *responseObject) {
            
            NSDictionary *part = @{@"partNumber": [NSNumber numberWithUnsignedInteger:i+1],
                                    @"etag": [responseObject objectForKey:@"etag"]
            };
            [uploadSuccess addObject:part];
            dispatch_group_leave(group);
        }
                    failure:^(NSError *error) {
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (number == uploadSuccess.count - 1) {
            [self endUploadTaskWithHost:host
                                 bucket:bucket
                        fileNameBase64:fileNameBase64
                               uploadId:uploadId
                            uploadToken:uploadToken
                                  parts:[uploadSuccess copy]
                                success:^(NSDictionary *responseObject) {
                success ? success() : nil;
            } failure:^(NSError *error) {
                failure ? failure() : nil;
            }];
        } else {
            failure ? failure() : nil;
        }
    });
    
}

- (void)uploadSubData:(NSData *)subData
                 host:(NSString *)host
               bucket:(NSString *)bucket
      fileNameBase64:(NSString *)fileNameBase64
                index:(NSUInteger)index
             uploadId:(NSString *)uploadId
          uploadToken:(NSString *)uploadToken
              success:(void (^)(NSDictionary *responseObject))success
              failure:(void (^)(NSError *error))failure {
    
    NSString *url = [NSString stringWithFormat:@"%@/buckets/%@/objects/%@/uploads/%@/%tu", host, bucket, fileNameBase64, uploadId, index+1];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = @"PUT";
    
    [request setValue:[NSString stringWithFormat:@"UpToken %@", uploadToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%tu", subData.length] forHTTPHeaderField:@"Content-Length"];
    
    request.HTTPBody = subData;
    
    KZLOG(@"allHTTPHeaderFields:%@", request.allHTTPHeaderFields);
    KZLOG(@"url: %@", request.URL);
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            KZLOG(@"upload failure :%@", error);
        } else {
            NSError *jsonErr;
            NSDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&jsonErr];
            if (jsonErr) {
                failure ? failure(error) : nil;
            } else {
                KZLOG(@"upload success: %@", responseObject);
                success ? success(responseObject) : nil;
            }
        }
    }];
    
    [task resume];
}

- (void)endUploadTaskWithHost:(NSString *)host
                          bucket:(NSString *)bucket
                 fileNameBase64:(NSString *)fileNameBase64
                     uploadId:(NSString *)uploadId
                  uploadToken:(NSString *)uploadToken
                        parts:(NSArray *)parts
                         success:(void (^)(NSDictionary *responseObject))success
                         failure:(void (^)(NSError *error))failure {
    
    NSString *url = [NSString stringWithFormat:@"%@/buckets/%@/objects/%@/uploads/%@", host, bucket, fileNameBase64, uploadId];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = @"POST";
    
    NSDictionary *parameters = @{@"parts": parts};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:nil];
    
    [request setValue:[NSString stringWithFormat:@"UpToken %@", uploadToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    KZLOG(@"allHTTPHeaderFields:%@", request.allHTTPHeaderFields);
    KZLOG(@"url: %@", request.URL);
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            KZLOG(@"upload failure :%@", error);
        } else {
            NSError *jsonErr;
            NSDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&jsonErr];
            if (jsonErr) {
                failure ? failure(error) : nil;
            } else {
                KZLOG(@"upload success: %@", responseObject);
                success ? success(responseObject) : nil;
            }
        }
    }];
    
    [task resume];
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
        _session = session;
    }
    return self;
}


@end
