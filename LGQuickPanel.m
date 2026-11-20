//
//  LGQuickPanel.m
//

#import "LGQuickPanel.h"
#import <QuartzCore/QuartzCore.h>

@implementation LGQuickItem
+ (instancetype)item:(NSString *)t symbol:(NSString *)s action:(NSString *)a {
    LGQuickItem *i = [LGQuickItem new];
    i.title = t; i.symbol = s; i.action = a;
    return i;
}
@end

@interface LGQuickPanel ()
@property (nonatomic, strong) UIVisualEffectView *glass;
@property (nonatomic, strong) UIView *container;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UIView *dim;
@property (nonatomic, assign) BOOL showing;
@end

@implementation LGQuickPanel

+ (instancetype)shared {
    static LGQuickPanel *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [LGQuickPanel new]; });
    return s;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.hidden = YES;
        [self buildUI];
    }
    return self;
}

- (void)buildUI {
    _container = [[UIView alloc] initWithFrame:CGRectZero];
    _container.backgroundColor = [UIColor clearColor];
    [self addSubview:_container];

    UIBlurEffect *e = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial];
    _glass = [[UIVisualEffectView alloc] initWithEffect:e];
    _glass.clipsToBounds = YES;
    _glass.layer.cornerRadius = 22.0;
    _glass.layer.cornerCurve = kCACornerCurveContinuous;
    _glass.layer.borderWidth = 0.7;
    _glass.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.5].CGColor;
    [_container addSubview:_glass];

    _stack = [[UIStackView alloc] initWithFrame:CGRectZero];
    _stack.axis = UILayoutConstraintAxisVertical;
    _stack.spacing = 2.0;
    _stack.alignment = UIStackViewAlignmentFill;
    _stack.distribution = UIStackViewDistributionFillEqually;
    [_container addSubview:_stack];

    UITapGestureRecognizer *tapOut = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(onBackgroundTap)];
    [self addGestureRecognizer:tapOut];
}

- (void)setItems:(NSArray<LGQuickItem *> *)items {
    _items = [items copy];
    for (UIView *v in [_stack.arrangedSubviews copy]) {
        [_stack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    NSInteger idx = 0;
    for (LGQuickItem *it in items) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.tag = idx++;
        b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        b.tintColor = [UIColor labelColor];

        UIImage *img = [UIImage systemImageNamed:it.symbol ?: @"circle"];
        [b setImage:img forState:UIControlStateNormal];

        NSMutableAttributedString *t = [[NSMutableAttributedString alloc]
            initWithString:[NSString stringWithFormat:@"  %@", it.title ?: @""]
                attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:15 weight:UIFontWeightMedium],
                             NSForegroundColorAttributeName:[UIColor labelColor]}];
        [b setAttributedTitle:t forState:UIControlStateNormal];
        b.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
        [b addTarget:self action:@selector(onItemTap:) forControlEvents:UIControlEventTouchUpInside];
        [_stack addArrangedSubview:b];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat rowH = 46.0;
    CGFloat panelW = MIN(230.0, W - 48.0);
    CGFloat panelH = MAX(rowH * 2.0, rowH * (CGFloat)MAX((NSInteger)1, (NSInteger)_items.count)) + 16.0;
    _container.frame = CGRectMake(0, 0, panelW, panelH);
    _glass.frame = _container.bounds;
    _stack.frame = CGRectMake(8, 8, panelW - 16, panelH - 16);
}

#pragma mark - 门轴动画

- (void)presentFromPoint:(CGPoint)point
                  inView:(UIView *)host
                    edge:(LGHingeEdge)edge
{
    if (self.showing) { [self dismiss]; return; }
    if (!host) return;

    self.frame = host.bounds;
    [host addSubview:self];
    self.hidden = NO;
    [self setNeedsLayout];
    [self layoutIfNeeded];

    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat H = CGRectGetHeight(self.bounds);
    CGFloat pw = CGRectGetWidth(_container.bounds);
    CGFloat ph = CGRectGetHeight(_container.bounds);

    // 面板落位：以触发点为基准，靠近左/右边缘
    CGFloat x = point.x - pw * 0.5;
    x = MAX(16.0, MIN(x, W - pw - 16.0));
    CGFloat y = point.y - ph - 12.0;
    y = MAX(16.0, MIN(y, H - ph - 16.0));

    CGRect target = CGRectMake(x, y, pw, ph);
    _container.frame = target;

    // 门轴：左边缘 / 右边缘 / 底边
    CGPoint anchor = CGPointMake(0.5, 0.5);
    CGFloat rotZ = 0.0;
    CATransform3D from = CATransform3DIdentity;
    switch (edge) {
        case LGHingeEdgeLeft:
            anchor = CGPointMake(0.0, 0.5);
            from = CATransform3DMakeRotation(-M_PI_2 * 0.92, 0, 1, 0);
            break;
        case LGHingeEdgeRight:
            anchor = CGPointMake(1.0, 0.5);
            from = CATransform3DMakeRotation(M_PI_2 * 0.92, 0, 1, 0);
            break;
        case LGHingeEdgeBottom:
            anchor = CGPointMake(0.5, 1.0);
            from = CATransform3DMakeRotation(-M_PI_2 * 0.92, 1, 0, 0);
            break;
        default:
            break;
    }
    (void)rotZ;

    // 设置 anchorPoint 后修正 position，避免位移
    [self setAnchor:anchor forView:_container];

    CATransform3D persp = CATransform3DIdentity;
    persp.m34 = -1.0 / 620.0;
    from = CATransform3DConcat(from, persp);
    _container.layer.transform = from;
    _container.layer.opacity = 0.0;

    self.backgroundColor = [UIColor clearColor];
    [UIView animateWithDuration:0.34
                          delay:0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self->_container.layer.transform = persp;
        self->_container.layer.opacity = 1.0;
    } completion:^(BOOL f) {
        self.showing = YES;
    }];
}

- (void)setAnchor:(CGPoint)anchor forView:(UIView *)v {
    CGPoint old = v.layer.anchorPoint;
    if (CGPointEqualToPoint(old, anchor)) return;
    CGRect b = v.bounds;
    CGPoint pos = v.layer.position;
    CGPoint d = CGPointMake((anchor.x - old.x) * CGRectGetWidth(b),
                            (anchor.y - old.y) * CGRectGetHeight(b));
    v.layer.anchorPoint = anchor;
    v.layer.position = CGPointMake(pos.x + d.x, pos.y + d.y);
}

- (void)dismiss {
    if (self.hidden) return;
    [UIView animateWithDuration:0.22 animations:^{
        self->_container.layer.opacity = 0.0;
        CATransform3D t = CATransform3DConcat(
            CATransform3DMakeRotation(-M_PI_2 * 0.85, 0, 1, 0),
            CATransform3DIdentity);
        self->_container.layer.transform = t;
    } completion:^(BOOL f) {
        self.showing = NO;
        self.hidden = YES;
        [self removeFromSuperview];
        self->_container.layer.transform = CATransform3DIdentity;
    }];
}

- (void)onBackgroundTap {
    CGPoint p = [self.gestureRecognizers.firstObject locationInView:self];
    if (!CGRectContainsPoint(_container.frame, p)) [self dismiss];
}

- (void)onItemTap:(UIButton *)sender {
    NSInteger i = sender.tag;
    if (i >= 0 && i < (NSInteger)_items.count && self.onSelect) {
        self.onSelect(_items[i]);
    }
    [self dismiss];
}

@end
