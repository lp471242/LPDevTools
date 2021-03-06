//
//  LPApiManager.m
//  LPNetWork
//
//  Created by lipeng on 17/3/24.
//  Copyright © 2017年 lpdev.com. All rights reserved.
//

#import "LPApiManager.h"
#import "LPCommonMacro.h"
#import "YYKit.h"
#import "LPCategory.h"

@interface LPApiManager ()

@property (nonatomic, strong) NSURLSessionDataTask *task;

@end

@implementation LPApiManager

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    if (self.task) {
        ASLog(@"取消数据请求 %@ %@\n",self,self.task);
        [self.task cancel];
        self.task = nil;
    }
}

+ (instancetype)getUrl:(NSString *)url
            parameters:(NSDictionary *)parameters
             className:(Class)className
         responseBlock:(ResponseBlock)responseBlock {
    LPApiManager *apiManager = [[LPApiManager alloc]initWithUrl:url params:parameters className:className rquestType:LPApiRequestTypeGet responseBlock:responseBlock];
    return apiManager;
}

+ (instancetype)postUrl:(NSString *)url
             parameters:(NSDictionary *)parameters
              className:(Class)className
          responseBlock:(ResponseBlock)responseBlock {
    LPApiManager *apiManager = [[LPApiManager alloc]initWithUrl:url params:parameters className:className rquestType:LPApiRequestTypePost responseBlock:responseBlock];
    return apiManager;
}

- (instancetype)initWithUrl:(NSString *)url params:(NSDictionary *)params className:(Class)className rquestType:(LPApiRequestType)requestType responseBlock:(ResponseBlock)responseBlock{
    if (self = [super init]) {
        [self loadDataWithUrl:url params:params className:className rquestType:requestType responseBlock:responseBlock];
    }
    return self;
}

//图片压缩处理
- (NSArray *)imageCompression:(NSArray *)images {
    NSMutableArray *files = @[].mutableCopy;
    for (NSInteger i = 0; i < images.count; i++) {
        if ([images[i] isKindOfClass:[UIImage class]]) {
            UIImage *image = images[i];
            image = [image scaledToSize:CGSizeMake(kScreen_Width, kScreen_Height)];
            image = [UIImage rotateImage:image];
            NSData *data = UIImageJPEGRepresentation(image, 0.6f);
            NSString *typeStr = @".png";
            NSString *str = [NSData contentTypeForImageData:data];
            if (![NSString isEmpty:str]) {
                typeStr = [NSString stringWithFormat:@".%@",str];
            }
            NSString *content = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
            NSDictionary *dic = @{@"Flag":@(i+1),@"Extension":typeStr,@"Data":content};
            [files addObject:dic];
        }
    }
    return files;
}

- (void)loadDataWithUrl:(NSString *)url params:(NSDictionary *)params className:(Class)className rquestType:(LPApiRequestType)requestType responseBlock:(ResponseBlock)responseBlock{
    self.task = [[LPNetWorkManager sharedManager] callApiWithUrl:url params:params requestType:requestType callBack:^(id responseObject, NSError *error) {
        ASLog(@"\nURL:%@\nparameters:%@\nResult:%@\n", url, params, error == nil ? responseObject : error);
        LPNetWorkResponse *response;
        if (error) {
            response = [[LPNetWorkResponse alloc]init];
            response.code = 10000;
            response.message = @"网络异常，请稍后再试！";
        }else {
            response = [[LPNetWorkResponse alloc]initWithResult:responseObject className:className];
        }
        responseBlock(response);
        [[LPNetWorkManager allTasks] removeObject:self.task];
        _task = nil;
    }];
    [self.task resume];
    if (self.task) {
        _task = self.task;
        [[LPNetWorkManager allTasks] addObject:self.task];
    }
}

+ (void)cancelAllRequest {
    @synchronized(self) {
        ASLog(@"%@",[LPNetWorkManager allTasks]);
        [[LPNetWorkManager allTasks] enumerateObjectsUsingBlock:^(NSURLSessionDataTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([task isKindOfClass:[NSURLSessionDataTask class]]) {
                [task cancel];
            }
        }];
        [[LPNetWorkManager allTasks] removeAllObjects];
    };
}

+ (void)cancelRequestWithURL:(NSString *)url {
    @synchronized(self) {
        [[LPNetWorkManager allTasks] enumerateObjectsUsingBlock:^(NSURLSessionDataTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([task isKindOfClass:[NSURLSessionDataTask class]]
                && [task.currentRequest.URL.absoluteString hasPrefix:url]) {
                [task cancel];
                [[LPNetWorkManager allTasks] removeObject:task];
                return;
            }
        }];
    };
}

@end


@implementation LPNetWorkResponse

- (instancetype)initWithResult:(NSDictionary *)result className:(Class)className {
    if (![result isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    self = [super init];
    if (self) {
        
        _code = [result[@"code"] integerValue];
        _message = result[@"msg"];
        _data = result[@"data"];
        if (className) {
            __block id data = _data;
            if ([data isKindOfClass:[NSDictionary class]]) {
                NSArray *defaults = @[@"list"];
                [defaults enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if ([_data.allKeys containsObject:obj]) {
                        data = _data[obj];
                        *stop = YES;
                    }
                }];
            }
            
            if (data == nil || [data isEqual:[NSNull null]]) {
                data = [data isKindOfClass:[NSArray class]] ? @{} : @[];
            }
            
            self.result =
            [data isKindOfClass:[NSDictionary class]] ? [className modelWithDictionary:data] : [NSArray modelArrayWithClass:className json:data];
            
            NSAssert(_result, @"Parse error!");
        }
    }
    return self;

}

- (BOOL)isSuccess {
    return  _code == 0;
}

@end
