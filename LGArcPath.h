//
//  LGArcPath.h
//  WCLiquidArc — 液态弧形悬浮栏
//
//  生成"上下双弧"带状路径，用于 Liquid Glass 胶囊的 mask 与描边
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LGArcPath : NSObject

/// 生成弧形带路径
/// @param rect      目标矩形
/// @param topSag    上边缘中点下沉量（正数表示中间向下凹）
/// @param bottomSag 下边缘中点下沉量
/// @param corner    两端圆角半径
+ (UIBezierPath *)bandInRect:(CGRect)rect
                      topSag:(CGFloat)topSag
                   bottomSag:(CGFloat)bottomSag
                      corner:(CGFloat)corner;

/// 计算弧形带在某 x 处的垂直中心（用于让按钮沿弧线排布）
+ (CGFloat)centerYAtX:(CGFloat)x
                 rect:(CGRect)rect
               topSag:(CGFloat)topSag
            bottomSag:(CGFloat)bottomSag
             thickness:(CGFloat)thickness;

/// 纯上弧（用于上排胶囊或高光）
+ (UIBezierPath *)arcLineInRect:(CGRect)rect sag:(CGFloat)sag;

@end

NS_ASSUME_NONNULL_END
