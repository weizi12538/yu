//
//  LGQuickPanel.h
//  快捷面板：门轴（铰链）旋转展开
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LGHingeEdge) {
    LGHingeEdgeLeft = 0,
    LGHingeEdgeRight,
    LGHingeEdgeBottom
};

@interface LGQuickItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *symbol;
@property (nonatomic, copy) NSString *action;    // URL scheme 或自定义标记
+ (instancetype)item:(NSString *)t symbol:(NSString *)s action:(NSString *)a;
@end

@interface LGQuickPanel : UIView

+ (instancetype)shared;

/// 从某点展开（以 anchor 为门轴）
- (void)presentFromPoint:(CGPoint)point
                  inView:(UIView *)host
                    edge:(LGHingeEdge)edge;

- (void)dismiss;

@property (nonatomic, copy) NSArray<LGQuickItem *> *items;
@property (nonatomic, copy) void (^onSelect)(LGQuickItem *item);

@end

NS_ASSUME_NONNULL_END
