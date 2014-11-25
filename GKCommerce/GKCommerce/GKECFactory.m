//
//  GKECFactory.m
//  GKCommerce
//
//  Created by 小悟空 on 11/26/14.
//  Copyright (c) 2014 GKCommerce. All rights reserved.
//

#import "GKECFactory.h"
#import "ECCartBackend.h"
#import "ECCartService.h"

@implementation GKECFactory

- (id<CartBackend>)cartBackend
{
    return [[ECCartBackend alloc] init];
}

- (id<CartService>)cartService
{
    return [[ECCartService alloc] init];
}
@end