//
//  KZUploadViaFormData.m
//  KZQiNiuObjectStore
//
//  Created by Khazan on 2021/3/15.
//

#import "KZUploadViaFormData.h"
#import "KZQiNiuObjectStoreConstants.h"
#import "KZUploadToken.h"

@interface KZUploadViaFormData ()

@property (nonatomic, strong) NSURLSession *session;

@end

@implementation KZUploadViaFormData

- (void)uploadWithData:(NSData *)data
              fileName:(NSString *)fileName
                  host:(NSString *)host
                bucket:(NSString *)bucket
             accessKey:(NSString *)accessKey
             secretKey:(NSString *)secretKey
               success:(void (^)(void))success
               failure:(void (^)(void))failure {
    
    NSString *uploadToken = [KZUploadToken tokenWithBucket:bucket fileName:fileName accessKey:accessKey secretKey:secretKey];

    NSURL *URL = [[NSURL alloc] initWithString:host];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:URL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
    request.HTTPMethod = @"POST";
    
    NSDictionary *params = @{@"token": uploadToken, @"key": fileName};
    
    NSString *boundary = @"werghnvt54wef654rjuhgb56trtg34tweuyrgf";
    request.allHTTPHeaderFields = @{
        @"Content-Type" : [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary]
    };
    
    NSString *name = @"file";
    NSString *mimeType = @"application/octet-stream";
    NSData *formData = [self formData:data boundary:boundary parameters:params name:name fileName:fileName mimeType:mimeType];
    
    request.HTTPBody = formData;
    
    [request setValue:[NSString stringWithFormat:@"%tu", formData.length] forHTTPHeaderField:@"Content-Length"];
    
    NSURLSessionDataTask *task = [self.session uploadTaskWithRequest:request fromData:nil completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            KZLOG(@"upload failure :%@", error);
            failure ? failure() : nil;
        } else {
            KZLOG(@"upload success :%@", [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil]);
            success ? success() : nil;
        }
    }];
    
    [task resume];
}


- (NSData *)formData:(NSData *)data boundary:(NSString *)boundary parameters:(NSDictionary *)parameters name:(NSString *)name fileName:(NSString *)fileName mimeType:(NSString *)mimeType {
    
    NSMutableData *postData = [[NSMutableData alloc] init];
    
    for (NSString *paramsKey in parameters) {
        NSString *pair = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n", boundary, paramsKey];
        [postData appendData:[pair dataUsingEncoding:NSUTF8StringEncoding]];
        
        id value = [parameters objectForKey:paramsKey];
        if ([value isKindOfClass:[NSString class]]) {
            [postData appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
        } else if ([value isKindOfClass:[NSData class]]) {
            [postData appendData:value];
        }
        [postData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    NSString *filePair = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"; filename=\"%@\"\nContent-Type:%@\r\n\r\n", boundary, name, fileName, mimeType];
    [postData appendData:[filePair dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:data];
    [postData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    return [postData copy];
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
