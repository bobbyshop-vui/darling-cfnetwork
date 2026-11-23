//
//  NSURLCredential.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSURLCredential.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSString.h>

@implementation NSURLCredential

+ (BOOL) supportsSecureCoding {
    return YES;
}

+ (NSURLCredential *) credentialWithUser: (NSString *) user
                                password: (NSString *) password
                             persistence: (NSURLCredentialPersistence) persistence
{
    return [[[self alloc] initWithUser: user
                              password: password
                           persistence: persistence] autorelease];
}

- (id) initWithUser: (NSString *) user
           password: (NSString *) password
        persistence: (NSURLCredentialPersistence) persistence
{
    if ((self = [super init])) {
        _user = [user copy];
        _password = [password copy];
        // Permanent storage is only possible for internet passwords in the
        // keychain; the credential itself keeps the requested value.
        _persistence = persistence;
    }
    return self;
}

+ (NSURLCredential *) credentialForTrust: (SecTrustRef) trust {
    return [[[self alloc] initWithTrust: trust] autorelease];
}

- (id) initWithTrust: (SecTrustRef) trust {
    if ((self = [super init])) {
        if (trust != NULL)
            _trust = (SecTrustRef) CFRetain(trust);
        _persistence = NSURLCredentialPersistenceForSession;
    }
    return self;
}

+ (NSURLCredential *) credentialWithIdentity: (SecIdentityRef) identity
                                certificates: (NSArray *) certArray
                                 persistence: (NSURLCredentialPersistence) persistence
{
    return [[[self alloc] initWithIdentity: identity
                              certificates: certArray
                               persistence: persistence] autorelease];
}

- (id) initWithIdentity: (SecIdentityRef) identity
           certificates: (NSArray *) certArray
            persistence: (NSURLCredentialPersistence) persistence
{
    if ((self = [super init])) {
        if (identity != NULL)
            _identity = (SecIdentityRef) CFRetain(identity);
        _certificates = [certArray copy];
        _persistence = persistence;
    }
    return self;
}

- (void) dealloc {
    [_user release];
    [_password release];
    [_certificates release];
    if (_identity != NULL)
        CFRelease(_identity);
    if (_trust != NULL)
        CFRelease(_trust);
    [super dealloc];
}

- (NSString *) user {
    return _user;
}

- (NSString *) password {
    return _password;
}

- (BOOL) hasPassword {
    return _password != nil;
}

- (SecIdentityRef) identity {
    return _identity;
}

- (NSArray *) certificates {
    return _certificates;
}

- (NSURLCredentialPersistence) persistence {
    return _persistence;
}

- (id) copyWithZone: (NSZone *) zone {
    // Credentials are immutable.
    return [self retain];
}

- (void) encodeWithCoder: (NSCoder *) coder {
    // Identities and trusts are not archivable; only the password based
    // state is written.
    [coder encodeObject: _user forKey: @"NS.user"];
    [coder encodeObject: _password forKey: @"NS.password"];
    [coder encodeInteger: (NSInteger) _persistence forKey: @"NS.persistence"];
    [coder encodeObject: _certificates forKey: @"NS.certificates"];
}

- (id) initWithCoder: (NSCoder *) coder {
    if ((self = [super init])) {
        _user = [[coder decodeObjectOfClass: [NSString class]
                                     forKey: @"NS.user"] copy];
        _password = [[coder decodeObjectOfClass: [NSString class]
                                         forKey: @"NS.password"] copy];
        _persistence = (NSURLCredentialPersistence)
                [coder decodeIntegerForKey: @"NS.persistence"];
        _certificates = [[coder decodeObjectOfClass: [NSArray class]
                                             forKey: @"NS.certificates"] copy];
    }
    return self;
}

- (BOOL) isEqual: (id) other {
    if (other == self)
        return YES;
    if (![other isKindOfClass: [NSURLCredential class]])
        return NO;

    NSURLCredential *o = other;
    if (_persistence != o->_persistence || _identity != o->_identity ||
        _trust != o->_trust)
        return NO;
    if (_user != o->_user && ![_user isEqual: o->_user])
        return NO;
    if (_password != o->_password && ![_password isEqual: o->_password])
        return NO;
    return _certificates == o->_certificates ||
           [_certificates isEqual: o->_certificates];
}

- (NSUInteger) hash {
    return [_user hash] ^ [_password hash] ^ (NSUInteger) _identity ^
           (NSUInteger) _trust;
}

@end
