//
//  LGLiquidBar.h
//  液态弧形底栏 —— 上排胶囊播放条 + 两侧圆钮 + 下排内凹弧带
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class LGLiquidBar;

@protocol LGLiquidBarDelegate <NSObject>
@optional
/// 点击左/右侧圆钮（slot 0=左 1=右）
- (void)liquidBar:(LGLiquidBar *)bar didTapOrb:(NSInteger)slot;
/// 点击弧带上的按钮（index 0..4）
- (void)liquidBar:(LGLiquidBar *)bar didTapArcItem:(NSInteger)index;
/// 点击播放条
- (void)liquidBarDidTapPlayer:(LGLiquidBar *)bar;
/// 点击播放条上的头像
- (void)liquidBarDidTapArtwork:(LGLiquidBar *)bar;
/// 中间条左右滑动切换（direction: -1 左滑 / +1 右滑）
- (void)liquidBar:(LGLiquidBar *)bar didSwipeBand:(NSInteger)direction;
@end

@interface LGLiquidBar : UIView

@property (nonatomic, weak, nullable) id<LGLiquidBarDelegate> delegate;

/// 当前曲目信息（nil 显示待播放状态）
- (void)setTrackTitle:(nullable NSString *)title
               artist:(nullable NSString *)artist
             artwork:(nullable UIImage *)artwork;

/// 播放状态
- (void)setPlaying:(BOOL)playing;

/// 弧带按钮图标名（SF Symbols）。传 nil 隐藏该项
- (void)setArcIcons:(NSArray<NSString *> *)icons;

/// 圆钮图标（slot 0/1），nil 隐藏
- (void)setOrbIcons:(NSArray<NSString *> *)icons;

/// 未读角标（弧带第 0 项），0 隐藏
- (void)setBadgeCount:(NSInteger)count;

/// 进度 0..1，用于播放条底部细线
- (void)setProgress:(CGFloat)progress;

/// 布局参数（弧度、厚度）
- (void)setTopSag:(CGFloat)topSag bottomSag:(CGFloat)bottomSag thickness:(CGFloat)thickness;

/// 使玻璃效果跟随明暗
- (void)refreshAppearance;

/// 整个底栏需要的高度
- (CGFloat)preferredHeight;

/// 右侧圆钮在指定坐标系中的位置（快捷面板锚点用）
- (CGRect)rightOrbFrameInView:(UIView *)view;

/// 左侧圆钮在指定坐标系中的位置
- (CGRect)leftOrbFrameInView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
