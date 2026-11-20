//
//  LGArcPath.m
//  液态弧形几何：底栏的上下双弧、内凹、胶囊轮廓
//

#import "LGArcPath.h"

@implementation LGArcPath

// 抛物线型弧线：在 [x0,x1] 上按 sag 下沉，x=t 时返回 y 偏移
static inline CGFloat LGSagAt(CGFloat t, CGFloat sag) {
    // t ∈ [-1, 1]，中点下沉最大
    return sag * (1.0 - t * t);
}

+ (UIBezierPath *)bandInRect:(CGRect)rect
                      topSag:(CGFloat)topSag
                   bottomSag:(CGFloat)bottomSag
                      corner:(CGFloat)corner
{
    CGFloat x0 = CGRectGetMinX(rect), x1 = CGRectGetMaxX(rect);
    CGFloat y0 = CGRectGetMinY(rect), y1 = CGRectGetMaxY(rect);
    CGFloat w  = x1 - x0;
    if (w <= 4.0) return [UIBezierPath bezierPath];

    // 上边缘：从左端向右，控制点在中点下沉
    // 期望中点下沉 topSag，二次贝塞尔中点下沉 = sag/2，故控制点取 2*topSag
    CGFloat topCtlY = y0 + topSag * 2.0;
    CGFloat botCtlY = y1 + bottomSag * 2.0;

    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(x0 + corner, y0)];
    [p addQuadCurveToPoint:CGPointMake(x1 - corner, y0)
              controlPoint:CGPointMake(x0 + w * 0.5, topCtlY)];

    // 右端圆角
    [p addQuadCurveToPoint:CGPointMake(x1, y0 + corner)
              controlPoint:CGPointMake(x1, y0)];
    [p addLineToPoint:CGPointMake(x1, y1 - corner)];
    [p addQuadCurveToPoint:CGPointMake(x1 - corner, y1)
              controlPoint:CGPointMake(x1, y1)];

    // 下边缘：从右向左
    [p addQuadCurveToPoint:CGPointMake(x0 + corner, y1)
              controlPoint:CGPointMake(x0 + w * 0.5, botCtlY)];

    // 左端圆角
    [p addQuadCurveToPoint:CGPointMake(x0, y1 - corner)
              controlPoint:CGPointMake(x0, y1)];
    [p addLineToPoint:CGPointMake(x0, y0 + corner)];
    [p addQuadCurveToPoint:CGPointMake(x0 + corner, y0)
              controlPoint:CGPointMake(x0, y0)];
    [p closePath];
    return p;
}

+ (CGFloat)centerYAtX:(CGFloat)x
                 rect:(CGRect)rect
               topSag:(CGFloat)topSag
            bottomSag:(CGFloat)bottomSag
             thickness:(CGFloat)thickness
{
    CGFloat x0 = CGRectGetMinX(rect), w = CGRectGetWidth(rect);
    CGFloat y0 = CGRectGetMinY(rect);
    if (w <= 0.0) return y0 + thickness * 0.5;

    CGFloat t = ((x - x0) / w) * 2.0 - 1.0;   // -1 .. 1
    if (t < -1.0) t = -1.0;
    if (t >  1.0) t =  1.0;

    CGFloat topY = y0 + LGSagAt(t, topSag);
    CGFloat botY = topY + thickness + LGSagAt(t, bottomSag);
    return (topY + botY) * 0.5;
}

+ (UIBezierPath *)arcLineInRect:(CGRect)rect sag:(CGFloat)sag {
    CGFloat x0 = CGRectGetMinX(rect), x1 = CGRectGetMaxX(rect);
    CGFloat y0 = CGRectGetMinY(rect), w = x1 - x0;
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(x0, y0)];
    [p addQuadCurveToPoint:CGPointMake(x1, y0)
              controlPoint:CGPointMake(x0 + w * 0.5, y0 + sag * 2.0)];
    return p;
}

@end
