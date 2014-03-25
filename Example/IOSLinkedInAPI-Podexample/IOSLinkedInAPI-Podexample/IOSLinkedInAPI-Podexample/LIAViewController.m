//
//  LIAViewController.m
//  IOSLinkedInAPI-Podexample
//
//  Created by Jacob von Eyben on 16/12/13.
//  Copyright (c) 2013 Eyben Consult ApS. All rights reserved.
//

#import "LIAViewController.h"
#import "AFHTTPRequestOperation.h"
#import "LIALinkedInApplication.h"

#import "LIAEngine.h"

#import <ReactiveCocoa/ReactiveCocoa.h>

static NSString* const LINKEDIN_CLIENT_ID = nil;//Your client id
static NSString* const LINKEDIN_CLIENT_SECRET = nil;//Your client secret

@interface LIAViewController ()

@property (nonatomic, strong) LIAEngine* engine;

@end

@implementation LIAViewController

@synthesize engine = _engine;

-(LIAEngine*)engine
{
   if ( !_engine )
   {
      NSParameterAssert(LINKEDIN_CLIENT_ID);
      NSParameterAssert(LINKEDIN_CLIENT_SECRET);

      LIALinkedInApplication *application = [LIALinkedInApplication applicationWithRedirectURL:@"http://www.ancientprogramming.com/liaexample"
                                                                                      clientId:LINKEDIN_CLIENT_ID
                                                                                  clientSecret:LINKEDIN_CLIENT_SECRET
                                                                                         state:@"DCEEFWF45453sdffef424"
                                                                                 grantedAccess:@[@"r_fullprofile", @"r_network"]];
      _engine = [ [ LIAEngine alloc ] initWithApplication: application presentingViewController: self ];
   }
   return _engine;
}

- (IBAction)didTapConnectWithLinkedIn:(id)sender {
   [ [ [ self.engine accessToken ] flattenMap:
      ^( NSString* access_token_ )
      {
         return [ self.engine signalWithMethod: @"GET"
                                          path: [ NSString stringWithFormat: @"https://api.linkedin.com/v1/people/~?oauth2_access_token=%@&format=json", access_token_ ] ];
      } ]
    subscribeNext:
    ^( id user_ )
    {
       NSLog(@"result: %@", user_);
    }
    error:
    ^( NSError* error_ )
    {
       NSLog(@"error: %@", error_ );
    }];
}

@end
