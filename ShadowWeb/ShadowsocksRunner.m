//
// Created by clowwindy on 14-2-27.
// Copyright (c) 2014 clowwindy. All rights reserved.
//

#import "ShadowsocksRunner.h"
#import "local.h"


@implementation ShadowsocksRunner {

}

+ (BOOL)settingsAreNotComplete {
    if ((![ShadowsocksRunner isUsingPublicServer]) && ([[NSUserDefaults standardUserDefaults] stringForKey:kShadowsocksIPKey] == nil ||
            [[NSUserDefaults standardUserDefaults] stringForKey:kShadowsocksPortKey] == nil ||
            [[NSUserDefaults standardUserDefaults] stringForKey:kShadowsocksPasswordKey] == nil)) {
        return YES;
    } else {
        return NO;
    }
}

+ (BOOL)runProxy {
    //看是否设置了自定义的服务器
    if (![ShadowsocksRunner settingsAreNotComplete]) {
        //设置了，执行local.m中的主函数。
        //这里估计就是去监听端口，实现流量代理了
        local_main();
        return YES;
    } else {
#ifdef DEBUG
        NSLog(@"warning: settings are not complete");
#endif
        return NO;
    }
}

+ (void)reloadConfig {
    //看是否配置了服务器信息
    if (![ShadowsocksRunner settingsAreNotComplete]) {
        //看是否使用了公共服务器
        if ([ShadowsocksRunner isUsingPublicServer]) {
            //使用了公共服务器
            //去local.m中设置服务器IP，端口，密码，加密方式
            set_config("106.186.124.182", "8911", "Shadowsocks", "aes-128-cfb");
            //void *memcpy(void*dest, const void *src, size_t n);
            memcpy(shadowsocks_key, "\x45\xd1\xd9\x9e\xbd\xf5\x8c\x85\x34\x55\xdd\x65\x46\xcd\x06\xd3", 16);
        } else {
            //如果没有使用公共服务器
            //取出加密方式
            NSString *v = [[NSUserDefaults standardUserDefaults] objectForKey:kShadowsocksEncryptionKey];
            if (!v) {
                v = @"aes-256-cfb";
            }
            //去local.m中设置服务器IP，端口，密码，加密方式
            NSString *sockIP = [[NSUserDefaults standardUserDefaults] stringForKey:kShadowsocksIPKey];
            NSString *sockPort = [[NSUserDefaults standardUserDefaults] stringForKey:kShadowsocksPortKey];
            NSString *sockPassword = [[NSUserDefaults standardUserDefaults] stringForKey:kShadowsocksPasswordKey];
            set_config([sockIP cStringUsingEncoding:NSUTF8StringEncoding], [sockPort cStringUsingEncoding:NSUTF8StringEncoding], [sockPassword cStringUsingEncoding:NSUTF8StringEncoding], [v cStringUsingEncoding:NSUTF8StringEncoding]);
        }
    }
}

+ (BOOL)openSSURL:(NSURL *)url {
    if (!url.host) {
        return NO;
    }
    NSString *urlString = [url absoluteString];
    int i = 0;
    NSString *errorReason = nil;
    while(i < 2) {
        if (i == 1) {
            NSData *data = [[NSData alloc] initWithBase64Encoding:url.host];
            NSString *decodedString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            urlString = decodedString;
        }
        i++;
        urlString = [urlString stringByReplacingOccurrencesOfString:@"ss://" withString:@"" options:NSAnchoredSearch range:NSMakeRange(0, urlString.length)];
        NSRange firstColonRange = [urlString rangeOfString:@":"];
        NSRange lastColonRange = [urlString rangeOfString:@":" options:NSBackwardsSearch];
        NSRange lastAtRange = [urlString rangeOfString:@"@" options:NSBackwardsSearch];
        if (firstColonRange.length == 0) {
            errorReason = @"colon not found";
            continue;
        }
        if (firstColonRange.location == lastColonRange.location) {
            errorReason = @"only one colon";
            continue;
        }
        if (lastAtRange.length == 0) {
            errorReason = @"at not found";
            continue;
        }
        if (!((firstColonRange.location < lastAtRange.location) && (lastAtRange.location < lastColonRange.location))) {
            errorReason = @"wrong position";
            continue;
        }
        NSString *method = [urlString substringWithRange:NSMakeRange(0, firstColonRange.location)];
        NSString *password = [urlString substringWithRange:NSMakeRange(firstColonRange.location + 1, lastAtRange.location - firstColonRange.location - 1)];
        NSString *IP = [urlString substringWithRange:NSMakeRange(lastAtRange.location + 1, lastColonRange.location - lastAtRange.location - 1)];
        NSString *port = [urlString substringWithRange:NSMakeRange(lastColonRange.location + 1, urlString.length - lastColonRange.location - 1)];
        [ShadowsocksRunner saveConfigForKey:kShadowsocksIPKey value:IP];
        [ShadowsocksRunner saveConfigForKey:kShadowsocksPortKey value:port];
        [ShadowsocksRunner saveConfigForKey:kShadowsocksPasswordKey value:password];
        [ShadowsocksRunner saveConfigForKey:kShadowsocksEncryptionKey value:method];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kShadowsocksUsePublicServer];
        [ShadowsocksRunner reloadConfig];
        return YES;
    }

    NSLog(@"%@", errorReason);
    return NO;
}

+(NSURL *)generateSSURL {
    if ([ShadowsocksRunner isUsingPublicServer]) {
        return nil;
    }
    NSString *parts = [NSString stringWithFormat:@"%@:%@@%@:%@",
                       [ShadowsocksRunner configForKey:kShadowsocksEncryptionKey],
                       [ShadowsocksRunner configForKey:kShadowsocksPasswordKey],
                       [ShadowsocksRunner configForKey:kShadowsocksIPKey],
                       [ShadowsocksRunner configForKey:kShadowsocksPortKey]];
    
    NSString *base64String = [[parts dataUsingEncoding:NSUTF8StringEncoding] base64Encoding];
    NSString *urlString = [NSString stringWithFormat:@"ss://%@", base64String];
    return [NSURL URLWithString:urlString];
}

+ (void)saveConfigForKey:(NSString *)key value:(NSString *)value {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)configForKey:(NSString *)key {
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

+ (void)setUsingPublicServer:(BOOL)use {
    [[NSUserDefaults standardUserDefaults] setBool:use forKey:kShadowsocksUsePublicServer];

}

+ (BOOL)isUsingPublicServer {
    NSNumber *usePublicServer = [[NSUserDefaults standardUserDefaults] objectForKey:kShadowsocksUsePublicServer];
    if (usePublicServer != nil) {
        return [usePublicServer boolValue];
    } else {
        return YES;
    }
}

@end
