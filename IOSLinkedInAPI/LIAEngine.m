#import "LIAEngine.h"

#import "LIALinkedInAuthorizationViewController.h"
#import "LIALinkedInApplication.h"

#import "NSString+LIAEncode.h"

#import <ReactiveCocoa/ReactiveCocoa.h>
#import <AFNetworking/AFNetworking.h>

static NSString* const LIAEngineAccessTokenKey = @"LIAEngineAccessTokenKey";
static NSString* const LIAEngineAccessCreatedKey = @"LIAEngineAccessCreatedKey";
static NSString* const LIAEngineAccessExpiresInKey = @"LIAEngineAccessExpiresInKey";

@interface LIAEngine ()

@property ( nonatomic, strong ) AFHTTPClient* httpClient;
@property ( nonatomic, strong ) LIALinkedInApplication* application;
@property ( nonatomic, strong ) UIViewController* presentingViewController;

@end

@implementation LIAEngine

-(instancetype)initWithApplication:( LIALinkedInApplication* )application_
          presentingViewController:( UIViewController* )controller_
{
   self = [ super init ];
   if ( self )
   {
      self.application = application_;
      self.presentingViewController = controller_;
      self.httpClient = [ [ AFHTTPClient alloc ] initWithBaseURL: [ NSURL URLWithString:@"https://www.linkedin.com" ] ];
   }
   return self;
}

-(BOOL)validToken
{
   NSUserDefaults* defaults_ = [ NSUserDefaults standardUserDefaults ];
   
   return [ [ NSDate date ] timeIntervalSince1970 ] < ( [ defaults_ doubleForKey: LIAEngineAccessCreatedKey ]
                                                       + [ defaults_ doubleForKey: LIAEngineAccessExpiresInKey ]);
}

-(NSString*)storedAccessToken
{
   return [ [ NSUserDefaults standardUserDefaults ] objectForKey: LIAEngineAccessTokenKey ];
}

-(AFHTTPRequestOperation*)operationWithMethod:( NSString* )method_
                                          URL:( NSURL* )url_
{
   NSMutableURLRequest* request_ = [ NSMutableURLRequest requestWithURL: url_ ];
   [ request_ setHTTPMethod: method_ ];
   return [ [ AFJSONRequestOperation alloc ] initWithRequest: request_ ];
}

-(AFHTTPRequestOperation*)operationWithMethod:( NSString* )method_
                                         path:( NSString* )path_
{
   return [ self operationWithMethod: method_
                                 URL: [ NSURL URLWithString: path_ relativeToURL: self.httpClient.baseURL ] ];
}

-(RACSignal*)signalWithMethod:( NSString* )method_
                         path:( NSString* )path_
{
   return [ self signalWithOperation: [ self operationWithMethod: method_ path: path_ ] ];
}

-(RACSignal*)signalWithMethod:( NSString* )method_
                          URL:( NSURL* )url_
{
   return [ self signalWithOperation: [ self operationWithMethod: method_ URL: url_ ] ];
}

-(RACSignal*)signalWithOperation:( AFHTTPRequestOperation* )operation_
{
   NSParameterAssert(operation_);
   return [ [ RACSignal createSignal: ^RACDisposable*( id<RACSubscriber> subscriber_ )
             {
                [ operation_ setCompletionBlockWithSuccess:
                 ^( AFHTTPRequestOperation* operation_, id response_ )
                 {
                    [ subscriber_ sendNext: response_ ];
                    [ subscriber_ sendCompleted ];
                 }
                                                  failure:
                 ^( AFHTTPRequestOperation* operation_, NSError* error_ )
                 {
                     [ subscriber_ sendError: error_ ];
                 }];
                
                [ self.httpClient enqueueHTTPRequestOperation: operation_ ];
                
                return [ RACDisposable disposableWithBlock:
                        ^{
                           [ operation_ cancel ];
                        }];
             } ] replayLazily ];
}

-(RACSignal*)accessTokenWithAuthorizationCode:( NSString* )code_
{
   NSParameterAssert(code_);

   NSString* request_format_ = @"/uas/oauth2/accessToken?grant_type=authorization_code&code=%@&redirect_uri=%@&client_id=%@&client_secret=%@";
   NSString* request_ = [ NSString stringWithFormat: request_format_
                         , code_
                         , [ self.application.redirectURL LIAEncode ]
                         , self.application.clientId
                         , self.application.clientSecret ];

   return [ [ self signalWithMethod: @"POST" path: request_ ]
           map: ^id( NSDictionary* json_ )
           {
              NSUserDefaults* default_ = [ NSUserDefaults standardUserDefaults ];

              NSString* token_ = [ json_ objectForKey: @"access_token" ];
              [ default_ setObject: token_ forKey: LIAEngineAccessTokenKey ];

              NSTimeInterval expires_in_ = [ [ json_ objectForKey: @"expires_in" ] doubleValue ];
              [ default_ setDouble: expires_in_
                            forKey: LIAEngineAccessExpiresInKey ];
              [ default_ setDouble: [ [ NSDate date ] timeIntervalSince1970 ]
                            forKey: LIAEngineAccessCreatedKey ];
              [ default_ synchronize ];
              
              return token_;
           } ];
}

-(RACSignal*)authorizationCode
{
   return [ [ RACSignal createSignal: ^RACDisposable*( id<RACSubscriber> subscriber_ )
             {
                LIALinkedInAuthorizationViewController* controller_ =
                [ [ LIALinkedInAuthorizationViewController alloc ] initWithApplication:
                 self.application
                                                                               success:
                 ^( NSString* code_ )
                 {
                    [ self.presentingViewController dismissViewControllerAnimated: YES completion: nil ];
                    [ subscriber_ sendNext: code_ ];
                    [ subscriber_ sendCompleted ];
                 }
                                                                                cancel:
                 ^{
                    [ self.presentingViewController dismissViewControllerAnimated: YES completion: nil ];
                    [ subscriber_ sendCompleted ];
                 }
                                                                               failure:
                 ^( NSError* error_ )
                {
                   [ self.presentingViewController dismissViewControllerAnimated: YES completion: nil ];
                   [ subscriber_ sendError: error_ ];
                 }];

                UINavigationController* navigation_controller_ = [ [ UINavigationController alloc ] initWithRootViewController: controller_ ];
                navigation_controller_.navigationBar.translucent = NO;

                if ( [ [ UIDevice currentDevice ] userInterfaceIdiom ] == UIUserInterfaceIdiomPad )
                {
                   navigation_controller_.modalPresentationStyle = UIModalPresentationFormSheet;
                }

                UIViewController* parent_controller_ = self.presentingViewController
                ?: [ [ UIApplication sharedApplication ] keyWindow ].rootViewController;

                [ parent_controller_ presentViewController: navigation_controller_
                                                  animated: YES
                                                completion: nil ];

                return nil;
             } ] replayLazily ];
}

-(RACSignal*)accessToken
{
   //if ( self.validToken )
   //   return [ RACSignal return: self.storedAccessToken ];

   return [ [ self authorizationCode ] flattenMap: ^( NSString* code_ )
           {
              return [ self accessTokenWithAuthorizationCode: code_ ];
           } ];
}

@end

@implementation LIAEngine (LIARequests)

-(RACSignal*)userPorfileWithAccessToken:( NSString* )access_token_
                                 fields:( NSArray* )fields_
{
   NSString* fields_selector_ = [ fields_ count ] > 0
      ? [ NSString stringWithFormat: @":(%@)", [ fields_ componentsJoinedByString: @"," ] ]
      : @"";

   return [ self signalWithMethod: @"GET"
                             path: [ NSString stringWithFormat: @"https://api.linkedin.com/v1/people/~%@?oauth2_access_token=%@&format=json", fields_selector_, access_token_ ] ];
}

@end
