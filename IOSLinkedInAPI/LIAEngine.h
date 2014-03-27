#import <Foundation/Foundation.h>

@class LIALinkedInApplication;
@class RACSignal;

@interface LIAEngine : NSObject

@property ( nonatomic, strong, readonly ) NSString* storedAccessToken;
@property ( nonatomic, assign, readonly ) BOOL validToken;

-(instancetype)initWithApplication:( LIALinkedInApplication* )application_
          presentingViewController:( UIViewController* )controller_;

-(RACSignal*)authorizationCode;
-(RACSignal*)accessTokenWithAuthorizationCode:( NSString* )code_;

-(RACSignal*)accessToken;

-(RACSignal*)signalWithMethod:( NSString* )method_
                         path:( NSString* )path_;

-(RACSignal*)signalWithMethod:( NSString* )method_
                          URL:( NSURL* )url_;

@end

@interface LIAEngine (LIARequests)

-(RACSignal*)userPorfileWithAccessToken:( NSString* )access_token_
                                 fields:( NSArray* )fields_;

@end
