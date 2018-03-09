#import "ReactNativeShareExtension.h"
#import "React/RCTRootView.h"
#import <MobileCoreServices/MobileCoreServices.h>

#define URL_IDENTIFIER @"public.url"
#define IMAGE_IDENTIFIER @"public.image"
#define TEXT_IDENTIFIER (NSString *)kUTTypePlainText
#define KEYVALUE_IDENTIFIER (NSString *)kUTTypePropertyList

NSExtensionContext* extensionContext;
UIView* rootView;

@implementation ReactNativeShareExtension {
    NSTimer *autoTimer;
    NSString* type;
    NSString* value;
}

- (UIView*) shareView {
    return nil;
}

RCT_EXPORT_MODULE();

- (void)viewDidLoad {
    [super viewDidLoad];

    //object variable for extension doesn't work for react-native. It must be assign to gloabl
    //variable extensionContext. in this way, both exported method can touch extensionContext
    extensionContext = self.extensionContext;

    rootView = [self shareView];
    if (rootView.backgroundColor == nil) {
        rootView.backgroundColor = [[UIColor alloc] initWithRed:1 green:1 blue:1 alpha:0.1];
    }
    
    self.view = rootView;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.view.transform = CGAffineTransformMakeTranslation(0, self.view.frame.size.height);
    [UIView animateWithDuration:0.25 animations:^
     {
         self.view.transform = CGAffineTransformIdentity;
     }];
}

RCT_EXPORT_METHOD(close) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.2
                         animations:^(void){
                             CGRect rect = rootView.frame;
                             rect.origin.y = rect.size.height;
                             rootView.frame = rect;
                         }
                         completion:^(BOOL finished){
                             [extensionContext completeRequestReturningItems:nil
                                                           completionHandler:nil];
                             @throw NSInternalInconsistencyException;
                         }];
    });
}

RCT_REMAP_METHOD(data,
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    [self extractDataFromContext: extensionContext withCallback:^(NSString* val, NSString* contentType, NSException* err) {
        if(err) {
            reject(@"error", err.description, nil);
        } else {
            resolve(@{
                      @"type": contentType,
                      @"value": val
                      });
        }
    }];
}

- (void)extractDataFromContext:(NSExtensionContext *)context withCallback:(void(^)(NSString *value, NSString* contentType, NSException *exception))callback {
    @try {
        NSExtensionItem *item = [context.inputItems firstObject];
        NSArray *attachments = item.attachments;

        __block NSItemProvider *urlProvider = nil;
        __block NSItemProvider *imageProvider = nil;
        __block NSItemProvider *textProvider = nil;
        __block NSItemProvider *keyValueProvider = nil;

        [attachments enumerateObjectsUsingBlock:^(NSItemProvider *provider, NSUInteger idx, BOOL *stop) {
            if ([provider hasItemConformingToTypeIdentifier:KEYVALUE_IDENTIFIER]){
                keyValueProvider = provider;
                *stop = YES;
            } else if([provider hasItemConformingToTypeIdentifier:URL_IDENTIFIER]) {
                urlProvider = provider;
                *stop = YES;
            } else if ([provider hasItemConformingToTypeIdentifier:TEXT_IDENTIFIER]){
                textProvider = provider;
                *stop = YES;
            } else if ([provider hasItemConformingToTypeIdentifier:IMAGE_IDENTIFIER]){
                imageProvider = provider;
                *stop = YES;
            }
        }];

        if (keyValueProvider) {
            [keyValueProvider loadItemForTypeIdentifier:KEYVALUE_IDENTIFIER options:nil completionHandler:^(NSDictionary *item, NSError *error) {
                NSString *encoded = [[NSString alloc]
                                    initWithData:[NSJSONSerialization
                                                  dataWithJSONObject:[item objectForKey:NSExtensionJavaScriptPreprocessingResultsKey]
                                                  options:0
                                                  error:&error]
                                    encoding:(NSUTF8StringEncoding)];
                if (callback) {
                    callback(encoded, @"application/json", nil);
                }
            }];
        } else if(urlProvider) {
            [urlProvider loadItemForTypeIdentifier:URL_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSURL *url = (NSURL *)item;

                if(callback) {
                    callback([url absoluteString], @"text/plain", nil);
                }
            }];
        } else if (imageProvider) {
            [imageProvider loadItemForTypeIdentifier:IMAGE_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSURL *url = (NSURL *)item;

                if(callback) {
                    callback([url absoluteString], [[[url absoluteString] pathExtension] lowercaseString], nil);
                }
            }];
        } else if (textProvider) {
            [textProvider loadItemForTypeIdentifier:TEXT_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSString *text = (NSString *)item;

                if(callback) {
                    callback(text, @"text/plain", nil);
                }
            }];
        } else {
            if(callback) {
                callback(nil, nil, [NSException exceptionWithName:@"Error" reason:@"couldn't find provider" userInfo:nil]);
            }
        }
    }
    @catch (NSException *exception) {
        if(callback) {
            callback(nil, nil, exception);
        }
    }
}

@end
