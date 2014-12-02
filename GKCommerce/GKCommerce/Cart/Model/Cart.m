//
//  Cart.m
//  goku-commerce.com
//
//  Created by 小悟空 on 14-8-17.
//  Copyright (c) 2014年 小悟空. All rights reserved.
//

#import "Cart.h"

@implementation Cart

- (id)init
{
    NSLog(@"请使用initWithUser构造对象。");
    strcpy(0, "exception");
    
    self = [super init];
    if (self) {
        self.items = [NSMutableArray array];
        
    }
    
    return self;
}

- (id)initWithUser:(User *)user
{
    self = [super init];
    if (self) {
        self.items = [NSMutableArray array];
        self.selected = [[NSMutableArray alloc] init];
        self.user = user;
    }
    return self;
}

- (NSDecimalNumber *)shipPrice
{
    if (!_shipPrice)
        _shipPrice = [[NSDecimalNumber alloc] initWithString:@"10"];
    return _shipPrice;
}

- (NSDecimalNumber *)totalPrice
{
    if (!_totalPrice)
        return [[NSDecimalNumber alloc] initWithFloat:
                ([self.price floatValue] + [self.shipPrice floatValue])];
    return _totalPrice;
}

- (void)addItem:(CartItem *)item
{
    [item addObserver:self forKeyPath:@"quantity"
              options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld
                 context:nil];
    [item addObserver:self forKeyPath:@"selected"
              options:NSKeyValueObservingOptionInitial context:nil];
    
    [self.items addObject:item];
    
    if (item.selected)
        [self.selected addObject:item];
    item.cart = self;
}

- (void)addItems:(NSArray *)items
{
    for (CartItem *item in items) {
        [self addItem:item];
    }
}

- (void)removeItem:(CartItem *)item
{
    [item removeObserver:self forKeyPath:@"quantity"];
    [item removeObserver:self forKeyPath:@"selected"];
    [self willChangeValueForKey:@"items"];
    [self.items removeObject:item];
    [self didChangeValueForKey:@"items"];
}

- (void)removeItemWithID:(NSInteger)itemID
{
    [[self itemWithID:itemID] clear];
}

- (CartItem *)itemWithID:(NSInteger)itemID
{
    __block CartItem *found = nil;
    [self.items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx,
                                                BOOL *stop) {
        CartItem *item = (CartItem *)obj;
        if (item.itemID == itemID)
            found = item;
    }];
    
    return found;
}

- (CartItem *)itemWithProductID:(NSInteger)productID
{
    __block CartItem *found = nil;
    [self.items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx,
                                                BOOL *stop) {
        CartItem *item = (CartItem *)obj;
        if (item.product.productID == productID)
            found = item;
    }];
    
    return found;
}

- (NSArray *)want
{
    NSMutableArray *wantBuy = [NSMutableArray array];
    for (CartItem *cartItem in self.items) {
        if(cartItem.selected) {
            [wantBuy addObject:cartItem];
        }
    }
    
    return wantBuy;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([@"quantity" isEqualToString:keyPath] &&
        [object isKindOfClass: [CartItem class]] &&
        0 == ((CartItem *)object).quantity) {
        [self removeItem:object];
    } else if ([@"selected" isEqualToString:keyPath]) {
        [self willChangeValueForKey:@"selectAll"];
        [self didChangeValueForKey:@"selectAll"];
    }
}

- (void)calculatePrice
{
    float price = 0.0f;
    float totalPrice = 0.0f;
    for (CartItem *cartItem in self.selected) {
        price += cartItem.product.price.floatValue * cartItem.quantity;
    }
    if (self.price.floatValue != price)
        self.price = [[NSDecimalNumber alloc] initWithFloat:price];
    totalPrice = price;
    float needForFreeShipping = self.freeShipping.floatValue - price;
    if (needForFreeShipping > 0)
        totalPrice = price + self.freight.floatValue;
    
    self.totalPrice = [[NSDecimalNumber alloc] initWithFloat:totalPrice];
}

- (BOOL)empty
{
    if (nil == self.items || self.items.count == 0)
        return YES;
    else
        return NO;
}

- (void)clear
{
    
    self.price = [[NSDecimalNumber alloc] initWithString:@"0.00"];
    self.marketPrice = [[NSDecimalNumber alloc] initWithString:@"0.00"];
    self.saving = [[NSDecimalNumber alloc] initWithString:@"0.00"];
    
    CartItem *item;
    NSInteger size = self.items.count - 1;
    while(size > -1) {
        item = (CartItem *)[self.items objectAtIndex:size];
        [item clear];
        size -= 1;
    }
    self.quantity = 0;
    self.items = [NSMutableArray array];
}

- (void)setSelectAll:(BOOL)selected
{
    for (CartItem *item in self.items)
        item.selected = selected;
}


- (BOOL)selectAll
{
    for (CartItem *item in self.items)
        if (!item.selected)
            return NO;
    
    return YES;
}

@end
