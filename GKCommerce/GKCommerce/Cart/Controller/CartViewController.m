//
//  CartViewController.m
//  goku-commerce.com
//
//  Created by 小悟空 on 14-7-29.
//  Copyright (c) 2014年 小悟空. All rights reserved.
//

#import "CartViewController.h"
#import "ProductDetailViewController.h"
#import "UIBindableTableViewCell.h"
#import "Dependency.h"
#import "CartStoreNameTableViewCell.h"

typedef enum {
    CartStoreNameCell,
    CartItemCell,
    CartOverviewCell
} CartCell;

@interface CartViewController ()
{
    UINavigationController *_loginNavigationController;
    BOOL skipUpdateSelect;
}

@end

@implementation CartViewController

- (void)setup
{
    skipUpdateSelect = NO;
    self.service = [[Dependency shared] cartService];
    self.service.delegate = self;
    
    App *app = [App shared];
    @weakify(self)
    [[RACObserve(app.currentUser, cart)
     filter:^BOOL(Cart* cart) {
         return !cart.empty;
     }]
     subscribeNext:^(Cart *cart) {
         @strongify(self);
         self.cart = cart;
         [self renderOverview];
         [self.tableView reloadData];
    }];
    [RACObserve(app.currentUser.cart, itemsOfStore)
     subscribeNext:^(id x) {
         @strongify(self);
         if (!app.currentUser.cart.empty)
             [self.tableView reloadData];
     }];
    [RACObserve([[[App shared] currentUser] cart], price)
     subscribeNext:^(id x) {
         @strongify(self);
         if (!app.currentUser.cart.empty)
             [self renderOverview];
     }];
    [RACObserve(app, currentUser) subscribeNext:^(User *user) {
        @strongify(self);
        self.user = user;
        if ([user authorized])
            [self.service fetchCartWithUser:app.currentUser];
    }];
    [RACObserve(self.user.cart, empty) subscribeNext:^(id empty) {
        @strongify(self);
        if ([empty boolValue] && !self.user.authorized) {
            self.navigationItem.rightBarButtonItem = nil;
            [self.view addSubview:[[CartEmptyViewController shared] view]];
        } else
            [[[CartEmptyViewController shared] view] removeFromSuperview];
    }];
    [RACObserve(app, currentUser.cart.selected)
     subscribeNext:^(NSMutableArray *selected) {
         [self renderOverview];
         [self renderSelectAll];
     }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setup];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.navigationItem.title = @"购物车";
    
    // setup table view
    for (NSString *identifier in @[@"CartItemOverviewTableViewCell",
                                   @"CartItemTableViewCell",
                                   @"CartStoreNameTableViewCell"])
        [self.tableView registerNib:[UINib nibWithNibName:identifier bundle:nil]
             forCellReuseIdentifier:identifier];

    self.tableView.tableFooterView = [[UIView alloc] init];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = UIColorFromRGB(0xf3f3f3);

    UIBarButtonItem *right;
    right = [[UIBarButtonItem alloc]
             initWithTitle:@"移除" style:UIBarButtonItemStylePlain
             target:self action:@selector(rightBarButtonClick:)];
    self.navigationItem.rightBarButtonItem = right;
}

- (void)renderSelectAll
{
    if (skipUpdateSelect) {
        skipUpdateSelect = NO;
        return;
    }
    BOOL isAllSelected = [[[[App shared] currentUser] cart] isAllSelected];
    self.selectAll.on = isAllSelected;
    
}

- (void)renderOverview
{
    self.totalPrice.text = [NSString stringWithFormat:@"合计:￥%.2f",
            [self.cart wantTotalPrice]];
}

#pragma mark - CartServiceDelegate

- (void)cartService:(id<CartService>)aCartService cart:(Cart *)aCart
              error:(NSError *)anError
{
}

- (void)cartService:(id<CartService>)aCartService didUpdateItem:(CartItem *)item
        oldQuantity:(NSInteger)anOldQuantity error:(NSError *)anError
{
    if (anError)
        [self.view showHUD:anError.localizedDescription afterDelay:2];
}

#pragma mark - Events
- (IBAction)didTapCheckout:(id)sender
{
    Cart *cart = [[Cart alloc] initWithUser:self.user];
    [cart calculatePrice];
}

- (void)didNavigationItemLeftButtonTap:(id)sender
{
    
}

- (void)didNavigationItemRightButtonTap:(id)sender
{
    [self.service removeItems:self.cart.itemsOfStore];
}

- (void)didCartItemBuy:(CartItem *)item
{
    NSInteger quantity = item.quantity;
    item.quantity += 1;
    
    [self.service updateItem:item oldQuantity:quantity];
}

- (void)didCartItemDrop:(CartItem *)item
{
    NSInteger quantity = item.quantity;
    if (quantity > 1) {
        item.quantity -= 1;
        [self.service updateItem:item oldQuantity:quantity];
    }
}

- (void)rightBarButtonClick:(id)sender
{
    [self.cart removeAllItems];
}

- (void)toggleButton:(GKToggleButton *)aToggleButton didSwitch:(BOOL)onOrOff
{
    skipUpdateSelect = YES;
    BOOL select = self.selectAll.on;
    [self.cart selectAllItems:select];
}

#pragma mark - UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView
heightForHeaderInSection:(NSInteger)section
{
    return 10.0f;
}

- (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat number = 0.0f;
    CartItemList *list;
    list = [self.cart.itemsOfStore objectAtIndex:indexPath.section];

    if (CartStoreNameCell == indexPath.row)
        number = 45.0f;
    else if (list.items.count >= indexPath.row) // CartItemCell
        number = 92.0f;
    else
        number = 36.0f;
    return number;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    if (0 == self.cart.itemsOfStore.count)
        return 0;
    
    CartItemList *list = [self.cart.itemsOfStore objectAtIndex:section];
    if (nil != list && list.items.count > 0) {
        return list.items.count + 2;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CartItemList *list;
    UITableViewCell *cell;
    list = [self.cart.itemsOfStore objectAtIndex:indexPath.section];
    
    if (CartStoreNameCell == indexPath.row)
        cell = [self storeNameCell:list];
    else if (list.items.count >= indexPath.row)
        cell = [self itemCellWithItem:[list itemAtIndex:indexPath.row - 1]];
    else
        cell = [self overviewCellWithList:list];
    id<UIBindableTableViewCell> bindable = (id<UIBindableTableViewCell>)cell;
    [bindable bind];
    return cell;
}

- (UITableViewCell *)storeNameCell:(CartItemList *)list
{
    CartStoreNameTableViewCell *cell;
    cell = [self.tableView
            dequeueReusableCellWithIdentifier:@"CartStoreNameTableViewCell"];
    cell.list = list;
    return cell;
}

- (UITableViewCell *)itemCellWithItem:(CartItem *)item
{
    CartItemTableViewCell *cell;
    cell = [self.tableView
            dequeueReusableCellWithIdentifier:@"CartItemTableViewCell"];
    cell.delegate = self;
    cell.item = item;
    return cell;
}

- (UITableViewCell *)overviewCellWithList:(CartItemList *)list
{
    CartItemOverviewTableViewCell *cell;
    cell = [self.tableView
            dequeueReusableCellWithIdentifier:@"CartItemOverviewTableViewCell"];
    cell.list = list;
    return cell;
}

- (void)tableView:(UITableView *)tableView
didEndDisplayingCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    id<UIBindableTableViewCell> bindable = (id<UIBindableTableViewCell>)cell;
    [bindable unbind];
}

- (void)cartItemPhotoClicked:(CartItem*)item
{
    ProductDetailViewController *viewController;
    viewController = [[ProductDetailViewController alloc]
                      initWithProductID:item.product.productID
                      user:self.user];
    [self.navigationController setHidesBottomBarWhenPushed:YES];
    [self.navigationController pushViewController:viewController animated:YES];
}
@end
