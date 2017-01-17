//
//  RWSearchFormViewController.m
//  TwitterInstant
//
//  Created by Colin Eberhardt on 02/12/2013.
//  Copyright (c) 2013 Colin Eberhardt. All rights reserved.
//

#import "RWSearchFormViewController.h"
#import "RWSearchResultsViewController.h"
#import <ReactiveCocoa.h>
#import "RACEXTScope.h"
#import "RWtweet.h"
#import "NSArray+LinqExtensions.h"

#import <Accounts/Accounts.h>
#import <Social/Social.h>

typedef NS_ENUM(NSInteger, RWTwitterInstantError) {
    RWTwitterInstantErrorAccessDenied,
    RWTwitterInstantErrorNoTwiitterAccounts,
    RWTwitterInstantErrorInvalidResponse
};

static NSString *const RWTwitterInstantDomain = @"TwitterInstant";

@interface RWSearchFormViewController ()

@property (weak, nonatomic) IBOutlet UITextField *searchText;

@property (strong, nonatomic) RWSearchResultsViewController *resultsViewController;

@property (strong, nonatomic) ACAccountStore *accountStore;
@property (strong, nonatomic) ACAccountType *twitterAccountType;

@end

@implementation RWSearchFormViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.title = @"Twitter Instant";
  
  [self styleTextField:self.searchText];
  
  self.resultsViewController = self.splitViewController.viewControllers[1];
    
    self.accountStore = [[ACAccountStore alloc] init];
    self.twitterAccountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    /*
     1. 如果有一个or多个订阅者，信号就是active；如果所有的订阅者被移除了，信号会被释放。
     2. 怎样取消一个信号的订阅。在completed或者error事件后，订阅者自动移除。也可以手动移除（RACDisposable）
     3.
     */
    /*
     The subscribeNext: block uses self in order to obtain a reference to the text field. Blocks capture and retain values 
     from the enclosing scope, therefore if a strong reference exists between self and this signal, it will result in a retain cycle.
     */
    /*
    __weak RWSearchFormViewController *weakSelf = self;
    [[self.searchText.rac_textSignal map:^id(NSString *text) {
        return [self isValidSearchText:text] ? [UIColor whiteColor] : [UIColor yellowColor];
    }] subscribeNext:^(UIColor *color) {
        weakSelf.searchText.backgroundColor = color;
    }];
     */
    
    @weakify(self)
    [[self.searchText.rac_textSignal map:^id(NSString *text) {
        return [self isValidSearchText:text] ? [UIColor whiteColor] : [UIColor yellowColor];
    }] subscribeNext:^(UIColor *color) {
        @strongify(self)
        self.searchText.backgroundColor = color;
    }];
    
    /*
    [[[[self requestAccessToTwitterSignal] then:^RACSignal *{
        @strongify(self)
        return self.searchText.rac_textSignal;
    }] filter:^BOOL(NSString *text) {
        @strongify(self)
        return [self isValidSearchText:text];
    }] subscribeNext:^(id x) {
        NSLog(@"%@", x);
    } error:^(NSError *error) {
        NSLog(@"An error occurred: %@", error);
    }];
     */
    
    [[[[[[[self requestAccessToTwitterSignal] then:^RACSignal *{
        @strongify(self)
        return self.searchText.rac_textSignal;
    }]
        filter:^BOOL(NSString *text) {
        @strongify(self)
        return [self isValidSearchText:text];
    }]
       throttle:0.5]
       flattenMap:^RACStream *(NSString *text) {
        @strongify(self)
        return [self signalForSearchWithText:text];
    }]
      deliverOn:[RACScheduler mainThreadScheduler]]
      subscribeNext:^(NSDictionary *jsonSearchResult) {
          NSLog(@"%@", jsonSearchResult);
          NSArray *statuses = jsonSearchResult[@"statuses"];
          NSArray *tweets = [statuses linq_select:^id(id item) {
              return [RWTweet tweetWithStatus:item];
          }];
          [self.resultsViewController displayTweets:tweets];
    } error:^(NSError *error) {
        NSLog(@"An error occurred: %@", error);
    }];
    
    //The throttle operation will only send a next event if another next event isn’t received within the given time period. 
    
}

- (BOOL)isValidSearchText:(NSString *)text {
    return text.length > 2;
}

- (RACSignal *)requestAccessToTwitterSignal {
    NSError *accessError = [NSError errorWithDomain:RWTwitterInstantDomain
                                               code:RWTwitterInstantErrorAccessDenied
                                           userInfo:nil];
    @weakify(self)
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self)
        [self.accountStore requestAccessToAccountsWithType:self.twitterAccountType
                                                   options:nil
                                                completion:^(BOOL granted, NSError *error) {
                                                    if (!granted) {
                                                        [subscriber sendError:accessError];
                                                    } else {
                                                        [subscriber sendNext:nil];
                                                        [subscriber sendCompleted];
                                                    }
                                                }];
        return nil;
    }];
}

- (SLRequest *)requestforTwitterSearchWithText:(NSString *)text {
    NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1.1/search/tweets.json"];
    NSDictionary *params = @{@"q": text};
    SLRequest *reqeust = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                            requestMethod:SLRequestMethodGET
                                                      URL:url
                                               parameters:params];
    return reqeust;
}

- (RACSignal *)signalForSearchWithText:(NSString *)text {
    NSError *noAccountError = [NSError errorWithDomain:RWTwitterInstantDomain
                                                  code:RWTwitterInstantErrorNoTwiitterAccounts
                                              userInfo:nil];
    NSError *invalidResponseError = [NSError errorWithDomain:RWTwitterInstantDomain
                                                        code:RWTwitterInstantErrorInvalidResponse
                                                    userInfo:nil];
    @weakify(self)
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self);
        SLRequest *request = [self requestforTwitterSearchWithText:text];
        NSArray *twitterAccounts = [self.accountStore accountsWithAccountType:self.twitterAccountType];
        if (twitterAccounts.count == 0) {
            [subscriber sendError:noAccountError];
        } else {
            [request setAccount:[twitterAccounts lastObject]];
            [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                if (urlResponse.statusCode == 200) {
                    NSDictionary *timelineData = [NSJSONSerialization JSONObjectWithData:responseData
                                                                                 options:NSJSONReadingAllowFragments
                                                                                   error:nil];
                    [subscriber sendNext:timelineData];
                    [subscriber sendCompleted];
                } else {
                    [subscriber sendError:invalidResponseError];
                }
            }];
        }
        return nil;
    }];
}

- (void)styleTextField:(UITextField *)textField {
  CALayer *textFieldLayer = textField.layer;
  textFieldLayer.borderColor = [UIColor grayColor].CGColor;
  textFieldLayer.borderWidth = 2.0f;
  textFieldLayer.cornerRadius = 0.0f;
}

@end
