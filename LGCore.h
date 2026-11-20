//
//  LGCore.h
//  配置持久化 + 悬浮栏生命周期 + 全局入口
//

#import <UIKit/UIKit.h>
#import "LGLiquidBar.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const LGConfigChangedNotification;

@interface LGConfig : NSObject

@property (class, nonatomic, readonly) LGConfig *shared;

// 总开关
@property (nonatomic, assign) BOOL enabled;
// 底栏
@property (nonatomic, assign) CGFloat topSag;
@property (nonatomic, assign) CGFloat bottomSag;
@property (nonatomic, assign) CGFloat thickness;
@property (nonatomic, assign) CGFloat bottomOffset;
@property (nonatomic, assign) CGFloat sideInset;
@property (nonatomic, assign) BOOL    hapticOnTap;
// 圆钮与弧带按钮（符号名，空串表示隐藏）
@property (nonatomic, copy) NSArray<NSString *> *orbIcons;
@property (nonatomic, copy) NSArray<NSString *> *arcIcons;
// 音乐
@property (nonatomic, copy) NSString *playlistId;
@property (nonatomic, copy) NSString *musicSource;   // netease / qq
@property (nonatomic, assign) BOOL    autoPlayOnLaunch;
// 快捷面板
@property (nonatomic, assign) BOOL    quickPanelEnabled;
@property (nonatomic, assign) NSInteger hingeEdge;   // 0 左 1 右 2 下

- (void)load;
- (void)save;

@end

@interface LGCore : NSObject

@property (class, nonatomic, readonly) LGCore *shared;

/// 启动悬浮栏（幂等）
- (void)start;
- (void)stop;
- (void)reloadUI;

/// 打开设置面板
- (void)presentSettings;

/// 供微信设置页注入的入口
- (UIViewController *)makeSettingsController;

@end

NS_ASSUME_NONNULL_END
