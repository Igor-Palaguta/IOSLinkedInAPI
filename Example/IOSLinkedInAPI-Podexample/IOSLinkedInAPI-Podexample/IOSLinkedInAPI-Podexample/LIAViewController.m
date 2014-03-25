//
//  LIAViewController.m
//  IOSLinkedInAPI-Podexample
//
//  Created by Jacob von Eyben on 16/12/13.
//  Copyright (c) 2013 Eyben Consult ApS. All rights reserved.
//

#import "LIAViewController.h"
#import "AFHTTPRequestOperation.h"
#import "LIALinkedInHttpClient.h"
#import "LIALinkedInApplication.h"

static NSString* const LINKEDIN_CLIENT_ID = nil;//Your client id
static NSString* const LINKEDIN_CLIENT_SECRET = nil;//Your client secret

@interface LIAViewController ()

@property (nonatomic, strong) LIALinkedInHttpClient* client;

@end

@implementation LIAViewController

@synthesize client = _client;

- (LIALinkedInHttpClient *)client {
   if ( !_client )
   {
      NSParameterAssert(LINKEDIN_CLIENT_ID);
      NSParameterAssert(LINKEDIN_CLIENT_SECRET);
      LIALinkedInApplication *application = [LIALinkedInApplication applicationWithRedirectURL:@"http://www.ancientprogramming.com/liaexample"
                                                                                      clientId:LINKEDIN_CLIENT_ID
                                                                                  clientSecret:LINKEDIN_CLIENT_SECRET
                                                                                         state:@"DCEEFWF45453sdffef424"
                                                                                 grantedAccess:@[@"r_fullprofile", @"r_network"]];
      _client = [LIALinkedInHttpClient clientForApplication:application presentingViewController:nil];
   }
   return _client;
}

- (IBAction)didTapConnectWithLinkedIn:(id)sender {
  [self.client getAuthorizationCode:^(NSString *code) {
    [self.client getAccessToken:code success:^(NSDictionary *accessTokenData) {
      NSString *accessToken = [accessTokenData objectForKey:@"access_token"];
      [self requestMeWithToken:accessToken];
    }                   failure:^(NSError *error) {
      NSLog(@"Quering accessToken failed %@", error);
    }];
  }                      cancel:^{
    NSLog(@"Authorization was cancelled by user");
  }                     failure:^(NSError *error) {
    NSLog(@"Authorization failed %@", error);
  }];
}

- (void)requestMeWithToken:(NSString *)accessToken {
   [self.client linkedInMethod: @"GET"
                           URL: [NSURL URLWithString: [ NSString stringWithFormat:@"https://api.linkedin.com/v1/people/~?oauth2_access_token=%@&format=json", accessToken]]
                       success: ^(NSDictionary* user)
    {
       NSLog(@"current user %@", user);
    }
                       failure: ^(NSError* error)
    {
       NSLog(@"error %@", error);
    }];
}

@end
