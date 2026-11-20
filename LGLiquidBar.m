//
//  LGLiquidBar.m
//

#import "LGLiquidBar.h"
#import "LGArcPath.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma mark - 玻璃材质

/// iOS 26 有 UIGlassEffect；旧系统退回 ultraThinMaterial
static UIVisualEffect *LGGlassEffect(void) {
    static Class glassCls = Nil;
    static BOOL probed = NO;
    if (!probed) {
        probed = YES;
        glassCls = NSClassFromString(@"UIGlassEffect");
    }
    if (glassCls) {
        SEL sel = NSSelectorFromString(@"effectWithStyle:");
        if ([glassCls respondsToSelector:sel]) {
            typedef id (*Fn)(id, SEL, NSInteger);
            Fn fn = (Fn)[glassCls methodForSelector:sel];
            @try {
                id e = fn(glassCls, sel, 0);
                if ([e isKindOfClass:[UIVisualEffect class]]) return (UIVisualEffect *)e;
            } @catch (__unused NSException *ex) {}
        }
    }
    if (@available(iOS 13.0, *)) {
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight];
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
}

#pragma mark - 玻璃容器

@interface LGGlassView : UIView
@property (nonatomic, strong) UIVisualEffectView *glass;
@property (nonatomic, strong) CAShapeLayer *stroke;
@property (nonatomic, strong) CAShapeLayer *shapeMask;
/// 自定义 outline（弧形带用），nil 表示用 bounds+cornerRadius
@property (nonatomic, copy) UIBezierPath *(^outlineProvider)(CGRect bounds);
@property (nonatomic, assign) CGFloat cornerRadius;
@end

@implementation LGGlassView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;

        _glass = [[UIVisualEffectView alloc] initWithEffect:LGGlassEffect()];
        _glass.userInteractionEnabled = NO;
        _glass.clipsToBounds = YES;
        [self addSubview:_glass];

        _stroke = [CAShapeLayer layer];
        _stroke.fillColor = [UIColor clearColor].CGColor;
        _stroke.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.55].CGColor;
        _stroke.lineWidth = 0.8;
        [self.layer addSublayer:_stroke];

        _shapeMask = [CAShapeLayer layer];
        _shapeMask.fillColor = [UIColor blackColor].CGColor;
        _glass.layer.mask = _shapeMask;
    }
    return self;
}

- (void)setCornerRadius:(CGFloat)r {
    _cornerRadius = r;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _glass.frame = self.bounds;

    UIBezierPath *path = nil;
    if (self.outlineProvider) {
        path = self.outlineProvider(self.bounds);
    } else {
        path = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                         cornerRadius:_cornerRadius];
    }
    if (!path) return;

    _shapeMask.frame = self.bounds;
    _shapeMask.path = path.CGPath;
    _stroke.frame = self.bounds;
    _stroke.path = path.CGPath;
}

- (void)refreshAppearance {
    self.glass.effect = LGGlassEffect();
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }
    _stroke.strokeColor = [UIColor colorWithWhite:(dark ? 1.0 : 1.0) alpha:(dark ? 0.35 : 0.62)].CGColor;
}

@end

#pragma mark - 圆钮

@interface LGOrbButton : UIControl
@property (nonatomic, strong) LGGlassView *bg;
@property (nonatomic, strong) UIImageView *icon;
@end

@implementation LGOrbButton
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _bg = [[LGGlassView alloc] initWithFrame:self.bounds];
        _bg.userInteractionEnabled = NO;
        _bg.cornerRadius = CGRectGetWidth(frame) * 0.5;
        [self addSubview:_bg];

        _icon = [[UIImageView alloc] initWithFrame:CGRectZero];
        _icon.contentMode = UIViewContentModeScaleAspectFit;
        _icon.tintColor = [UIColor labelColor];
        [self addSubview:_icon];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _bg.frame = self.bounds;
    _bg.cornerRadius = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds)) * 0.5;
    CGFloat s = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds)) * 0.42;
    _icon.frame = CGRectMake((CGRectGetWidth(self.bounds) - s) * 0.5,
                             (CGRectGetHeight(self.bounds) - s) * 0.5, s, s);
}
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.12 animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.93, 0.93) : CGAffineTransformIdentity;
    }];
}
@end

#pragma mark - 主视图

@interface LGLiquidBar () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) LGGlassView *playerCapsule;
@property (nonatomic, strong) UIImageView *artworkView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *prevBtn;
@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UIButton *nextBtn;
@property (nonatomic, strong) UIView  *progressTrack;
@property (nonatomic, strong) UIView  *progressFill;

@property (nonatomic, strong) LGOrbButton *leftOrb;
@property (nonatomic, strong) LGOrbButton *rightOrb;

@property (nonatomic, strong) LGGlassView *arcBand;
@property (nonatomic, strong) NSMutableArray<LGOrbButton *> *arcItems;
@property (nonatomic, strong) UILabel *badgeLabel;

@property (nonatomic, assign) CGFloat topSag;
@property (nonatomic, assign) CGFloat bottomSag;
@property (nonatomic, assign) CGFloat thickness;
@property (nonatomic, assign) CGFloat progress;
@property (nonatomic, assign) BOOL playing;
@end

@implementation LGLiquidBar

static const CGFloat kTopRowH   = 46.0;
static const CGFloat kRowGap    = 8.0;
static const CGFloat kSidePad   = 0.0;
static const CGFloat kOrbSize   = 46.0;

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _topSag    = 10.0;
        _bottomSag = 14.0;
        _thickness = 58.0;
        _arcItems  = [NSMutableArray array];
        self.backgroundColor = [UIColor clearColor];
        [self buildSubviews];
        [self installGestures];
    }
    return self;
}

- (void)buildSubviews {
    // 上排播放胶囊
    _playerCapsule = [[LGGlassView alloc] initWithFrame:CGRectZero];
    _playerCapsule.cornerRadius = kTopRowH * 0.5;
    [self addSubview:_playerCapsule];

    _artworkView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _artworkView.contentMode = UIViewContentModeScaleAspectFill;
    _artworkView.clipsToBounds = YES;
    _artworkView.layer.cornerRadius = 14.0;
    _artworkView.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    _artworkView.userInteractionEnabled = YES;
    [_artworkView addGestureRecognizer:[[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(onArtworkTap)]];
    [_playerCapsule addSubview:_artworkView];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    _titleLabel.textColor = [UIColor labelColor];
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _titleLabel.text = @"未播放";
    [_playerCapsule addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _subtitleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    _subtitleLabel.textColor = [UIColor secondaryLabelColor];
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _subtitleLabel.text = @"点击搜索音乐";
    [_playerCapsule addSubview:_subtitleLabel];

    _prevBtn  = [self makeTinyButton:@"backward.fill"  action:@selector(onPrev)];
    _playBtn  = [self makeTinyButton:@"play.fill"      action:@selector(onPlay)];
    _nextBtn  = [self makeTinyButton:@"forward.fill"   action:@selector(onNext)];
    [_playerCapsule addSubview:_prevBtn];
    [_playerCapsule addSubview:_playBtn];
    [_playerCapsule addSubview:_nextBtn];

    _progressTrack = [[UIView alloc] initWithFrame:CGRectZero];
    _progressTrack.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.18];
    _progressTrack.layer.cornerRadius = 1.0;
    [_playerCapsule addSubview:_progressTrack];

    _progressFill = [[UIView alloc] initWithFrame:CGRectZero];
    _progressFill.backgroundColor = [UIColor labelColor];
    _progressFill.layer.cornerRadius = 1.0;
    [_progressTrack addSubview:_progressFill];

    // 两侧圆钮
    _leftOrb  = [[LGOrbButton alloc] initWithFrame:CGRectZero];
    _rightOrb = [[LGOrbButton alloc] initWithFrame:CGRectZero];
    _leftOrb.tag = 0; _rightOrb.tag = 1;
    [_leftOrb  addTarget:self action:@selector(onOrb:) forControlEvents:UIControlEventTouchUpInside];
    [_rightOrb addTarget:self action:@selector(onOrb:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_leftOrb];
    [self addSubview:_rightOrb];
    [_leftOrb.icon  setImage:[UIImage systemImageNamed:@"gearshape.fill"]];
    [_rightOrb.icon setImage:[UIImage systemImageNamed:@"folder.fill"]];

    // 弧带
    _arcBand = [[LGGlassView alloc] initWithFrame:CGRectZero];
    __weak typeof(self) weakSelf = self;
    _arcBand.outlineProvider = ^UIBezierPath *(CGRect b) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return nil;
        return [LGArcPath bandInRect:b
                              topSag:self.topSag
                           bottomSag:self.bottomSag
                              corner:MIN(28.0, CGRectGetHeight(b) * 0.5)];
    };
    [self addSubview:_arcBand];

    // 弧带按钮 5 个
    NSArray *icons = @[@"envelope.fill", @"person.2.fill", @"", @"location.north.circle.fill", @"person.crop.circle"];
    for (NSInteger i = 0; i < 5; i++) {
        LGOrbButton *item = [[LGOrbButton alloc] initWithFrame:CGRectZero];
        item.tag = i;
        item.backgroundColor = [UIColor clearColor];
        item.bg.hidden = YES;                  // 弧带内不放玻璃，直接用点击区
        [item addTarget:self action:@selector(onArcItem:) forControlEvents:UIControlEventTouchUpInside];
        NSString *n = icons[i];
        if (n.length > 0) [item.icon setImage:[UIImage systemImageNamed:n]];
        [_arcBand addSubview:item];
        [_arcItems addObject:item];
    }
    // 中间大头像
    LGOrbButton *mid = _arcItems[2];
    mid.icon.contentMode = UIViewContentModeScaleAspectFill;
    mid.icon.clipsToBounds = YES;
    mid.icon.layer.cornerRadius = 26.0;
    mid.icon.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];

    // 角标
    _badgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _badgeLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    _badgeLabel.textColor = [UIColor whiteColor];
    _badgeLabel.backgroundColor = [UIColor systemRedColor];
    _badgeLabel.textAlignment = NSTextAlignmentCenter;
    _badgeLabel.layer.cornerRadius = 8.0;
    _badgeLabel.clipsToBounds = YES;
    _badgeLabel.hidden = YES;
    [_arcBand addSubview:_badgeLabel];
}

- (UIButton *)makeTinyButton:(NSString *)symbol action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    b.tintColor = [UIColor labelColor];
    b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)installGestures {
    // 中间条左右滑动切换
    UISwipeGestureRecognizer *left  = [[UISwipeGestureRecognizer alloc]
        initWithTarget:self action:@selector(onSwipeLeft)];
    left.direction = UISwipeGestureRecognizerDirectionLeft;
    left.delegate = self;

    UISwipeGestureRecognizer *right = [[UISwipeGestureRecognizer alloc]
        initWithTarget:self action:@selector(onSwipeRight)];
    right.direction = UISwipeGestureRecognizerDirectionRight;
    right.delegate = self;

    [_playerCapsule addGestureRecognizer:left];
    [_playerCapsule addGestureRecognizer:right];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(onPlayerTap)];
    [_playerCapsule addGestureRecognizer:tap];
}

#pragma mark - 布局

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat orb = kOrbSize;
    CGFloat gap = kRowGap;

    // 上排
    CGFloat capsuleX = orb + gap;
    CGFloat capsuleW = W - (orb + gap) * 2.0;
    if (capsuleW < 120.0) capsuleW = MAX(120.0, W - 2 * (orb + gap));

    _leftOrb.frame  = CGRectMake(0, 0, orb, orb);
    _rightOrb.frame = CGRectMake(W - orb, 0, orb, orb);
    _playerCapsule.frame = CGRectMake(capsuleX, 0, capsuleW, kTopRowH);
    _playerCapsule.cornerRadius = kTopRowH * 0.5;

    // 胶囊内部
    CGFloat pad = 8.0;
    CGFloat art = kTopRowH - pad * 2.0;
    _artworkView.frame = CGRectMake(pad, pad, art, art);
    _artworkView.layer.cornerRadius = art * 0.5;

    CGFloat btnW = 26.0;
    CGFloat rightEdge = capsuleW - pad;
    _nextBtn.frame = CGRectMake(rightEdge - btnW, (kTopRowH - btnW) * 0.5, btnW, btnW);
    _playBtn.frame = CGRectMake(rightEdge - btnW * 2 - 4, (kTopRowH - btnW) * 0.5, btnW, btnW);
    _prevBtn.frame = CGRectMake(rightEdge - btnW * 3 - 8, (kTopRowH - btnW) * 0.5, btnW, btnW);

    CGFloat textX = CGRectGetMaxX(_artworkView.frame) + 8.0;
    CGFloat textW = CGRectGetMinX(_prevBtn.frame) - textX - 6.0;
    if (textW < 20.0) textW = 20.0;
    _titleLabel.frame    = CGRectMake(textX, 8.0, textW, 17.0);
    _subtitleLabel.frame = CGRectMake(textX, 25.0, textW, 14.0);

    CGFloat trackW = capsuleW - pad * 2 - art - 8.0;
    _progressTrack.frame = CGRectMake(textX, kTopRowH - 5.0, MAX(20.0, trackW), 2.0);
    [self layoutProgress];

    // 弧带
    CGFloat arcTop = kTopRowH + gap;
    CGFloat arcH   = kThickness + _topSag + _bottomSag;
    _arcBand.frame = CGRectMake(kSidePad, arcTop, W - kSidePad * 2, arcH);

    CGRect bandBounds = _arcBand.bounds;
    NSInteger n = _arcItems.count;
    CGFloat insetX = 26.0;
    CGFloat usable = CGRectGetWidth(bandBounds) - insetX * 2.0;
    for (NSInteger i = 0; i < n; i++) {
        LGOrbButton *item = _arcItems[i];
        CGFloat cx = insetX + (n > 1 ? usable * i / (CGFloat)(n - 1) : usable * 0.5);
        CGFloat cy = [LGArcPath centerYAtX:cx
                                      rect:bandBounds
                                    topSag:_topSag
                                 bottomSag:_bottomSag
                                 thickness:_thickness];
        BOOL isMid = (i == 2);
        CGFloat sz = isMid ? 52.0 : 44.0;
        item.frame = CGRectMake(cx - sz * 0.5, cy - sz * 0.5, sz, sz);
        item.icon.layer.cornerRadius = isMid ? sz * 0.5 : 0;
        if (isMid) {
            item.icon.frame = CGRectMake(2, 2, sz - 4, sz - 4);
            item.icon.layer.cornerRadius = (sz - 4) * 0.5;
        }
    }

    // 角标贴在第 0 项右上
    if (_arcItems.count > 0 && !_badgeLabel.hidden) {
        LGOrbButton *first = _arcItems[0];
        _badgeLabel.frame = CGRectMake(CGRectGetMaxX(first.frame) - 12.0,
                                       CGRectGetMinY(first.frame) - 2.0, 16.0, 16.0);
    }
}

- (void)layoutProgress {
    CGFloat w = CGRectGetWidth(_progressTrack.bounds);
    CGFloat p = MAX(0.0, MIN(1.0, _progress));
    _progressFill.frame = CGRectMake(0, 0, w * p, CGRectGetHeight(_progressTrack.bounds));
}

#pragma mark - 对外

- (void)setTrackTitle:(NSString *)title artist:(NSString *)artist artwork:(UIImage *)artwork {
    _titleLabel.text = title.length ? title : @"未播放";
    _subtitleLabel.text = artist.length ? artist : @"点击搜索音乐";
    if (artwork) {
        _artworkView.image = artwork;
        _arcItems[2].icon.image = artwork;
    } else {
        _artworkView.image = nil;
        _arcItems[2].icon.image = [UIImage systemImageNamed:@"music.note"];
    }
}

- (void)setPlaying:(BOOL)playing {
    _playing = playing;
    [_playBtn setImage:[UIImage systemImageNamed:(playing ? @"pause.fill" : @"play.fill")]
              forState:UIControlStateNormal];
}

- (void)setArcIcons:(NSArray<NSString *> *)icons {
    for (NSInteger i = 0; i < _arcItems.count; i++) {
        LGOrbButton *item = _arcItems[i];
        if (i == 2) continue;                     // 中间是头像
        NSString *n = (i < (NSInteger)icons.count) ? icons[i] : nil;
        BOOL hide = (n.length == 0);
        item.hidden = hide;
        if (!hide) [item.icon setImage:[UIImage systemImageNamed:n]];
    }
    [self setNeedsLayout];
}

- (void)setOrbIcons:(NSArray<NSString *> *)icons {
    NSArray<LGOrbButton *> *orbs = @[_leftOrb, _rightOrb];
    for (NSInteger i = 0; i < orbs.count; i++) {
        LGOrbButton *o = orbs[i];
        NSString *n = (i < (NSInteger)icons.count) ? icons[i] : nil;
        BOOL hide = (n.length == 0);
        o.hidden = hide;
        if (!hide) [o.icon setImage:[UIImage systemImageNamed:n]];
    }
    [self setNeedsLayout];
}

- (void)setBadgeCount:(NSInteger)count {
    _badgeLabel.hidden = (count <= 0);
    _badgeLabel.text = count > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)count];
    [self setNeedsLayout];
}

- (void)setProgress:(CGFloat)progress {
    _progress = progress;
    [self layoutProgress];
}

- (void)setTopSag:(CGFloat)topSag bottomSag:(CGFloat)bottomSag thickness:(CGFloat)thickness {
    _topSag = topSag;
    _bottomSag = bottomSag;
    _thickness = thickness;
    [self setNeedsLayout];
}

- (void)refreshAppearance {
    [_playerCapsule refreshAppearance];
    [_arcBand refreshAppearance];
    [_leftOrb.bg refreshAppearance];
    [_rightOrb.bg refreshAppearance];
}

/// 整个底栏需要的高度
- (CGFloat)preferredHeight {
    return kTopRowH + kRowGap + _thickness + _topSag + _bottomSag;
}

- (CGRect)rightOrbFrameInView:(UIView *)view {
    if (!view) return CGRectZero;
    return [self convertRect:_rightOrb.frame toView:view];
}

- (CGRect)leftOrbFrameInView:(UIView *)view {
    if (!view) return CGRectZero;
    return [self convertRect:_leftOrb.frame toView:view];
}

#pragma mark - 事件

- (void)onOrb:(LGOrbButton *)sender {
    if ([_delegate respondsToSelector:@selector(liquidBar:didTapOrb:)])
        [_delegate liquidBar:self didTapOrb:sender.tag];
}
- (void)onArcItem:(LGOrbButton *)sender {
    if ([_delegate respondsToSelector:@selector(liquidBar:didTapArcItem:)])
        [_delegate liquidBar:self didTapArcItem:sender.tag];
}
- (void)onPlayerTap {
    if ([_delegate respondsToSelector:@selector(liquidBarDidTapPlayer:)])
        [_delegate liquidBarDidTapPlayer:self];
}
- (void)onArtworkTap {
    if ([_delegate respondsToSelector:@selector(liquidBarDidTapArtwork:)])
        [_delegate liquidBarDidTapArtwork:self];
}
- (void)onSwipeLeft {
    if ([_delegate respondsToSelector:@selector(liquidBar:didSwipeBand:)])
        [_delegate liquidBar:self didSwipeBand:-1];
}
- (void)onSwipeRight {
    if ([_delegate respondsToSelector:@selector(liquidBar:didSwipeBand:)])
        [_delegate liquidBar:self didSwipeBand:1];
}
- (void)onPrev {
    if ([_delegate respondsToSelector:@selector(liquidBar:didSwipeBand:)])
        [_delegate liquidBar:self didSwipeBand:-1];
}
- (void)onNext {
    if ([_delegate respondsToSelector:@selector(liquidBar:didSwipeBand:)])
        [_delegate liquidBar:self didSwipeBand:1];
}
- (void)onPlay {
    self.playing = !self.playing;
    if ([_delegate respondsToSelector:@selector(liquidBarDidTapPlayer:)])
        [_delegate liquidBarDidTapPlayer:self];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g
       shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)o {
    return YES;
}

@end
