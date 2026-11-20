//
//  LGEntry.m
//  插件入口：初始化、微信设置页注入「液态底栏」
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "LGCore.h"
#import "LGSettingsController.h"

static const void *kLGInjectedKey = &kLGInjectedKey;

#pragma mark - 设置页探测

/// 判断是否微信的「设置」根页面
static BOOL LGLooksLikeSettingsVC(UIViewController *vc) {
    if (!vc) return NO;
    NSString *cls = NSStringFromClass([vc class]);
    if (!cls.length) return NO;
    if (![cls containsString:@"Setting"] && ![cls containsString:@"setting"]) return NO;

    // 排除掉一批明显不是根设置的
    NSArray *blacklist = @[@"Cell", @"Section", @"Nav", @"Navigation", @"Item",
                           @"Switch", @"Model", @"Manager", @"Controller2"];
    for (NSString *b in blacklist) {
        if ([cls containsString:b]) {
            // 只放行以 Controller 结尾且不含 Cell/Item 的
            if (![b isEqualToString:@"Controller2"]) return NO;
        }
    }
    if (![vc isKindOfClass:[UITableViewController class]] &&
        ![vc.view isKindOfClass:[UITableView class]]) {
        // 允许内部含 tableView 的情况
        __block BOOL hasTable = NO;
        [vc.view.subviews enumerateObjectsUsingBlock:^(UIView *v, NSUInteger i, BOOL *stop) {
            if ([v isKindOfClass:[UITableView class]]) { hasTable = YES; *stop = YES; }
        }];
        if (!hasTable) return NO;
    }
    return YES;
}

static void LGInjectEntry(UIViewController *vc) {
    if (objc_getAssociatedObject(vc, kLGInjectedKey)) return;
    objc_setAssociatedObject(vc, kLGInjectedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"液态底栏" forState:UIControlStateNormal];
    [btn setImage:[UIImage systemImageNamed:@"rectangle.bottomthird.inset.filled"]
         forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    btn.tintColor = [UIColor systemBlueColor];
    [btn sizeToFit];

    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:btn];
    [btn addTarget:vc action:@selector(lg_openSettings) forControlEvents:UIControlEventTouchUpInside];

    // 挂到导航栏右侧；若已有右侧项则追加
    NSMutableArray *right = [NSMutableArray array];
    if (vc.navigationItem.rightBarButtonItems) [right addObjectsFromArray:vc.navigationItem.rightBarButtonItems];
    [right insertObject:item atIndex:0];
    vc.navigationItem.rightBarButtonItems = right;
}

#pragma mark - Swizzle

@implementation UIViewController (LGEntryHook)

- (void)lg_viewDidAppear:(BOOL)animated {
    [self lg_viewDidAppear:animated];
    if (LGLooksLikeSettingsVC(self)) {
        LGInjectEntry(self);
    }
}

- (void)lg_openSettings {
    LGSettingsController *s = [[LGSettingsController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:s];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

@end

static void LGInstallSettingsHook(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    Class cls = [UIViewController class];
    Method m1 = class_getInstanceMethod(cls, @selector(viewDidAppear:));
    Method m2 = class_getInstanceMethod(cls, @selector(lg_viewDidAppear:));
    if (m1 && m2) method_exchangeImplementations(m1, m2);
}

#pragma mark - 启动

__attribute__((constructor))
static void LGConstructor(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        LGInstallSettingsHook();

        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidFinishLaunchingNotification
                        object:nil queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *n) {
            // 延迟一点，等宿主界面就绪
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [[LGCore shared] start];
            });
        }];

        // 若已经启动过（注入晚于 app 启动）
        if ([UIApplication sharedApplication].keyWindow) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [[LGCore shared] start];
            });
        }
    });
}
