//
//  NSURLSession.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSURLSession.h>
#import <Foundation/NSURLConnection.h>
#import <Foundation/NSURLResponse.h>
#import <Foundation/NSOperation.h>
#import <Foundation/NSError.h>
#import <objc/runtime.h>

const int64_t NSURLSessionTransferSizeUnknown = -1LL;
NSString* const NSURLSessionDownloadTaskResumeData = @"NSURLSessionDownloadTaskResumeData";

@implementation NSURLSession

+ (void)initialize
{
    static dispatch_once_t once = 0L;
    dispatch_once(&once, ^{
        Class cls = objc_lookUpClass("__NSCFURLSession");
        assert(cls != Nil);
        class_setSuperclass(self, cls);
    });
}

@end

@interface NSURLSessionTask ()
@property (readwrite) NSUInteger taskIdentifier;
@property (readwrite, copy) NSURLRequest *originalRequest;
@property (readwrite, copy) NSURLRequest *currentRequest;
@property (readwrite, copy) NSURLResponse *response;
@property (readwrite) int64_t countOfBytesReceived;
@property (readwrite) int64_t countOfBytesExpectedToReceive;
@property (readwrite) NSURLSessionTaskState state;
@property (readwrite, copy) NSError *error;
@end

@implementation NSURLSessionTask

@synthesize taskIdentifier = _taskIdentifier;
@synthesize originalRequest = _originalRequest;
@synthesize currentRequest = _currentRequest;
@synthesize response = _response;
@synthesize countOfBytesReceived = _countOfBytesReceived;
@synthesize countOfBytesSent = _countOfBytesSent;
@synthesize countOfBytesExpectedToSend = _countOfBytesExpectedToSend;
@synthesize countOfBytesExpectedToReceive = _countOfBytesExpectedToReceive;
@synthesize taskDescription = _taskDescription;
@synthesize state = _state;
@synthesize error = _error;

- (id)initWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler
{
    static volatile int64_t nextIdentifier = 0;
    self = [super init];
    if (self != nil)
    {
        _originalRequest = [request copy];
        _currentRequest = [request copy];
        _completionHandler = [completionHandler copy];
        _taskIdentifier = (NSUInteger)__sync_add_and_fetch(&nextIdentifier, 1);
        _state = NSURLSessionTaskStateSuspended;
        _countOfBytesExpectedToReceive = NSURLSessionTransferSizeUnknown;
    }
    return self;
}

- (void)dealloc
{
    [_originalRequest release];
    [_currentRequest release];
    [_response release];
    [_error release];
    [_taskDescription release];
    [_completionHandler release];
    [super dealloc];
}

// The session is not retained: the task only needs it to find its delegate and queue while loading.
- (void)_setSession:(NSURLSession *)session
{
    _xcSession = session;
}

- (NSOperationQueue *)_callbackQueue
{
    static NSOperationQueue *fallbackQueue = nil;
    static dispatch_once_t once = 0L;
    NSOperationQueue *queue = [_xcSession delegateQueue];
    if (queue == nil)
    {
        dispatch_once(&once, ^{
            fallbackQueue = [[NSOperationQueue alloc] init];
            [fallbackQueue setMaxConcurrentOperationCount:1];
        });
        queue = fallbackQueue;
    }
    return queue;
}

- (void)_startLoading
{
    @synchronized (self)
    {
        if (_xcStarted)
        {
            return;
        }
        _xcStarted = YES;
    }
    [self retain];
    NSURLSession *session = _xcSession;
    [NSURLConnection sendAsynchronousRequest:_currentRequest queue:[self _callbackQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (_state == NSURLSessionTaskStateCompleted)
        {
            // cancelled while loading: the cancellation already reported its error
            if (_completionHandler != nil)
            {
                void (^handler)(NSData *, NSURLResponse *, NSError *) = _completionHandler;
                _completionHandler = nil;
                handler(nil, nil, _error);
                [handler release];
            }
            [self release];
            return;
        }
        [self setResponse:response];
        [self setError:error];
        if (response != nil)
        {
            [self setCountOfBytesExpectedToReceive:[response expectedContentLength]];
        }
        [self setCountOfBytesReceived:(int64_t)[data length]];

        id delegate = [session delegate];
        if (error == nil && data != nil && [delegate respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)])
        {
            [delegate URLSession:session dataTask:(NSURLSessionDataTask *)self didReceiveData:data];
        }
        [self setState:NSURLSessionTaskStateCompleted];
        if (_completionHandler != nil)
        {
            void (^handler)(NSData *, NSURLResponse *, NSError *) = _completionHandler;
            _completionHandler = nil;
            handler(data, response, error);
            [handler release];
        }
        else if ([delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)])
        {
            [delegate URLSession:session task:self didCompleteWithError:error];
        }
        [self release];
    }];
}

@end

@implementation NSURLSessionDataTask
@end

@implementation NSURLSessionDownloadTask
@end

@implementation NSURLSessionUploadTask
@end

@implementation NSURLSessionConfiguration

static NSURLSessionConfiguration *_defaultSessionConfiguration = nil;

+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
	if (_defaultSessionConfiguration == nil) {
		_defaultSessionConfiguration = [[NSURLSessionConfiguration alloc] init];
	}

	return _defaultSessionConfiguration;
}

@end
