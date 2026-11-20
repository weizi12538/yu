//
//  LGCore.m
//

#import "LGCore.h"
#import "LGQuickPanel.h"
#import "LGAudioEngine.h"
#import "LGSettingsController.h"

NSString *const LGConfigChangedNotification = @"LGConfigChangedNotification";

static NSString *const kLGSuite = @"com.wclg.liquidarc";

#pragma mark - 配置

@implementation LGConfig

+ (LGConfig *)shared {
    static LGConfig *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [LGConfig new];
        [s load];
    });
    return s;
}

- (NSUserDefaults *)defaults {
    return [[NSUserDefaults alloc] initWithSuiteName:kLGSuite] ?: [NSUserDefaults standardUserDefaults];
}

- (void)load {
    NSUserDefaults *d = [self defaults];
    NSDictionary *def = @{
        @"enabled": @YES,
        @"topSag": @10.0,
        @"bottomSag": @14.0,
        @"thickness": @58.0,
        @"bottomOffset": @(-8.0),
        @"sideInset": @12.0,
        @"haptic": @YES,
        @"orbIcons": @[@"gearshape.fill", @"folder.fill"],
        @"arcIcons": @[@"envelope.fill", @"person.2.fill", @"", @"location.north.circle.fill", @"person.crop.circle"],
        @"musicSource": @"netease",
        @"playlistId": @"",
        @"autoPlay": @NO,
        @"quickEnabled": @YES,
        @"hingeEdge": @0
    };
    [d registerDefaults:def];

    _enabled      = [d boolForKey:@"enabled"];
    _topSag       = [d doubleForKey:@"topSag"];
    _bottomSag    = [d doubleForKey:@"bottomSag"];
    _thickness    = [d doubleForKey:@"thickness"];
    _bottomOffset = [d doubleForKey:@"bottomOffset"];
    _sideInset    = [d doubleForKey:@"sideInset"];
    _hapticOnTap  = [d boolForKey:@"haptic"];

    NSArray *orb = [d arrayForKey:@"orbIcons"];
    _orbIcons = orb.count == 2 ? orb : def[@"orbIcons"];
    NSArray *arc = [d arrayForKey:@"arcIcons"];
    _arcIcons = arc.count == 5 ? arc : def[@"arcIcons"];

    _playlistId  = [d stringForKey:@"playlistId"] ?: @"";
    _musicSource = [d stringForKey:@"musicSource"] ?: @"netease";
    _autoPlayOnLaunch = [d boolForKey:@"autoPlay"];
    _quickPanelEnabled = [d boolForKey:@"quickEnabled"];
    _hingeEdge = [d integerForKey:@"hingeEdge"];
}

- (void)save {
    NSUserDefaults *d = [self defaults];
    [d setBool:_enabled forKey:@"enabled"];
    [d setDouble:_topSag forKey:@"topSag"];
    [d setDouble:_bottomSag forKey:@"bottomSag"];
    [d setDouble:_thickness forKey:@"thickness"];
    [d setDouble:_bottomOffset forKey:@"bottomOffset"];
    [d setDouble:_sideInset forKey:@"sideInset"];
    [d setBool:_hapticOnTap forKey:@"haptic"];
    [d setObject:_orbIcons forKey:@"orbIcons"];
    [d setObject:_arcIcons forKey:@"arcIcons"];
    [d setObject:_playlistId forKey:@"playlistId"];
    [d setObject:_musicSource forKey:@"musicSource"];
    [d setBool:_autoPlayOnLaunch forKey:@"autoPlay"];
    [d setBool:_quickPanelEnabled forKey:@"quickEnabled"];
    [d setInteger:_hingeEdge forKey:@"hingeEdge"];
    [d synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:LGConfigChangedNotification object:nil];
}

@end

#pragma mark - 悬浮窗口

@interface LGFloatingWindow : UIWindow
@property (nonatomic, weak) UIView *interactiveView;
@end

@implementation LGFloatingWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *v = [super hitTest:point withEvent:event];
    // 只在底栏区域接收触摸，其余穿透给微信
    if (self.interactiveView) {
        CGPoint p = [self convertPoint:point toView:self.interactiveView];
        if (!CGRectContainsPoint(self.interactiveView.bounds, p)) {
            // 快捷面板展开时允许其接收
            for (UIView *sub in self.subviews) {
                if ([sub isKindOfClass:[LGQuickPanel class]] && !sub.hidden) {
                    CGPoint q = [self convertPoint:point toView:sub];
                    if (CGRectContainsPoint(sub.bounds, q)) return v;
                }
            }
            return nil;
        }
    }
    return v;
}

@end

#pragma mark - 主控

@interface LGCore () <LGLiquidBarDelegate>
@property (nonatomic, strong) LGFloatingWindow *window;
@property (nonatomic, strong) LGLiquidBar *bar;
@property (nonatomic, strong) NSTimer *uiTimer;
@end

@implementation LGCore

+ (LGCore *)shared {
    static LGCore *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [LGCore new]; });
    return s;
}

- (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        LGConfig *cfg = [LGConfig shared];
        if (!cfg.enabled) return;
        if (self.window) { [self reloadUI]; return; }

        [[LGAudioEngine shared] start];

        [self buildWindow];
        [self bindNotifications];

        if (cfg.autoPlayOnLaunch && cfg.playlistId.length) {
            [[LGAudioEngine shared] loadPlaylist:cfg.playlistId
                                         source:cfg.musicSource
                                     completion:^(NSArray<LGSong *> *songs, NSError *err) {
                if (songs.count) [[LGAudioEngine shared] playSong:songs.firstObject];
            }];
        }
    });
}

- (void)buildWindow {
    LGConfig *cfg = [LGConfig shared];
    UIWindow *host = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (!w.hidden && w.windowLevel == UIWindowLevelNormal) { host = w; break; }
    }
    CGRect screen = (host ? host.bounds : [UIScreen mainScreen].bounds);

    LGFloatingWindow *win = [[LGFloatingWindow alloc] initWithFrame:screen];
    win.windowLevel = UIWindowLevelAlert - 1;
    win.backgroundColor = [UIColor clearColor];
    win.hidden = NO;
    win.rootViewController = [UIViewController new];
    win.rootViewController.view.backgroundColor = [UIColor clearColor];

    LGLiquidBar *bar = [[LGLiquidBar alloc] initWithFrame:CGRectZero];
    bar.delegate = self;
    [bar setTopSag:cfg.topSag bottomSag:cfg.bottomSag thickness:cfg.thickness];
    [bar setOrbIcons:cfg.orbIcons];
    [bar setArcIcons:cfg.arcIcons];
    [win.rootViewController.view addSubview:bar];

    win.interactiveView = bar;
    self.window = win;
    self.bar = bar;

    [self layoutBar];
    [self refreshFromEngine];
}

- (void)layoutBar {
    if (!self.bar || !self.window) return;
    LGConfig *cfg = [LGConfig shared];
    CGRect b = self.window.bounds;
    CGFloat side = cfg.sideInset;
    CGFloat w = CGRectGetWidth(b) - side * 2.0;
    CGFloat h = [self.bar preferredHeight];
    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeBottom = self.window.safeAreaInsets.bottom;
    }
    CGFloat y = CGRectGetHeight(b) - h - safeBottom + cfg.bottomOffset;
    self.bar.frame = CGRectMake(side, y, w, h);
}

- (void)bindNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(onAudioChanged)
        name:LGAudioStateChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(onConfigChanged)
        name:LGConfigChangedNotification object:nil];

    __weak typeof(self) ws = self;
    self.uiTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
        [ws onAudioChanged];
    }];
}

- (void)onConfigChanged {
    LGConfig *cfg = [LGConfig shared];
    if (!cfg.enabled) { [self stop]; return; }
    if (!self.window) { [self start]; return; }
    [self reloadUI];
}

- (void)reloadUI {
    LGConfig *cfg = [LGConfig shared];
    [self.bar setTopSag:cfg.topSag bottomSag:cfg.bottomSag thickness:cfg.thickness];
    [self.bar setOrbIcons:cfg.orbIcons];
    [self.bar setArcIcons:cfg.arcIcons];
    [self layoutBar];
    [self.bar refreshAppearance];
}

- (void)onAudioChanged {
    if (!self.bar) return;
    LGAudioEngine *e = [LGAudioEngine shared];
    LGSong *s = e.currentSong;
    if (s) {
        [self.bar setTrackTitle:s.name artist:s.artist artwork:nil];
    }
    [self.bar setPlaying:e.isPlaying];
    [self.bar setProgress:e.progress];
}

- (void)stop {
    [self.uiTimer invalidate];
    self.uiTimer = nil;
    self.bar = nil;
    self.window.hidden = YES;
    self.window = nil;
}

#pragma mark - LGLiquidBarDelegate

- (void)liquidBar:(LGLiquidBar *)bar didTapOrb:(NSInteger)slot {
    if ([LGConfig shared].hapticOnTap) {
        UIImpactFeedbackGenerator *g = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [g impactOccurred];
    }
    if (slot == 0) {
        [self presentSettings];
    } else {
        [self showQuickPanelFromOrb];
    }
}

- (void)showQuickPanelFromOrb {
    LGConfig *cfg = [LGConfig shared];
    if (!cfg.quickPanelEnabled) return;

    LGQuickPanel *p = [LGQuickPanel shared];
    p.items = [self defaultQuickItems];
    __weak typeof(self) ws = self;
    p.onSelect = ^(LGQuickItem *item) { [ws handleQuickItem:item]; };

    UIView *host = self.window.rootViewController.view;
    CGRect orb = self.bar.rightOrbFrameInView(host);
    CGPoint pt = CGPointMake(CGRectGetMidX(orb), CGRectGetMinY(orb));
    [p presentFromPoint:pt inView:host edge:(LGHingeEdge)cfg.hingeEdge];
}

- (NSArray<LGQuickItem *> *)defaultQuickItems {
    return @[
        [LGQuickItem item:@"扫一扫"     symbol:@"qrcode.viewfinder"   action:@"weixin://scanqrcode"],
        [LGQuickItem item:@"收付款"     symbol:@"creditcard.fill"     action:@"weixin://wxpay/bizpayurl"],
        [LGQuickItem item:@"朋友圈"     symbol:@"photo.on.rectangle"  action:@"weixin://moments"],
        [LGQuickItem item:@"收藏"       symbol:@"bookmark.fill"       action:@"weixin://favorites"],
        [LGQuickItem item:@"搜一搜"     symbol:@"magnifyingglass"     action:@"weixin://search"]
    ];
}

- (void)handleQuickItem:(LGQuickItem *)item {
    NSString *a = item.action;
    if (!a.length) return;
    NSURL *u = [NSURL URLWithString:a];
    if (!u) return;
    UIApplication *app = [UIApplication sharedApplication];
    if ([app canOpenURL:u]) {
        [app openURL:u options:@{} completionHandler:nil];
    }
}

- (void)liquidBar:(LGLiquidBar *)bar didTapArcItem:(NSInteger)index {
    if (index == 2) { [self presentSettings]; return; }
    NSArray *acts = @[@"weixin://moments", @"weixin://contacts", @"", @"weixin://search", @"weixin://profile"];
    if (index < (NSInteger)acts.count) {
        NSString *a = acts[index];
        if (a.length) {
            NSURL *u = [NSURL URLWithString:a];
            if (u) [[UIApplication sharedApplication] openURL:u options:@{} completionHandler:nil];
        }
    }
}

- (void)liquidBarDidTapPlayer:(LGLiquidBar *)bar {
    LGAudioEngine *e = [LGAudioEngine shared];
    if (!e.currentSong) { [self presentSettings]; return; }
    [e togglePlayPause];
    [self onAudioChanged];
}

- (void)liquidBarDidTapArtwork:(LGLiquidBar *)bar {
    [self presentSettings];
}

- (void)liquidBar:(LGLiquidBar *)bar didSwipeBand:(NSInteger)direction {
    LGAudioEngine *e = [LGAudioEngine shared];
    if (direction < 0) [e previous]; else [e next];
    [self onAudioChanged];
}

#pragma mark - 设置

- (void)presentSettings {
    UIViewController *vc = [self makeSettingsController];
    if (!vc) return;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    UIViewController *top = self.window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    [top presentViewController:nav animated:YES completion:nil];
}

- (UIViewController *)makeSettingsController {
    return [[LGSettingsController alloc] initWithStyle:UITableViewStyleInsetGrouped];
}

@end
