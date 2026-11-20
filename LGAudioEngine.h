//
//  LGAudioEngine.h
//  音乐引擎：TM API（TrollMusic 桥）优先，缺失时降级到网易云公开接口
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const LGAudioStateChangedNotification;

@interface LGSong : NSObject
@property (nonatomic, copy) NSString *songId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, copy) NSString *picString;
@property (nonatomic, copy) NSString *lrcString;
@property (nonatomic, copy) NSString *source;   // netease / qq
+ (instancetype)fromDict:(NSDictionary *)d source:(NSString *)src;
@end

@interface LGAudioEngine : NSObject

@property (class, nonatomic, readonly) LGAudioEngine *shared;

/// TM 桥是否可用（同步探测，需在主线程首次调用后才有结果）
@property (nonatomic, readonly) BOOL tmAvailable;

/// 当前曲目 / 播放状态
@property (nonatomic, readonly, nullable) LGSong *currentSong;
@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic, readonly) CGFloat progress;      // 0..1
@property (nonatomic, readonly) NSTimeInterval currentTime;
@property (nonatomic, readonly) NSTimeInterval duration;

/// 当前歌单
@property (nonatomic, copy, readonly) NSArray<LGSong *> *playlist;

/// 启动引擎（创建隐藏 WebView、配置音频会话）
- (void)start;

/// 歌单 / 搜索
- (void)loadPlaylist:(NSString *)playlistId
              source:(NSString *)source
          completion:(void (^)(NSArray<LGSong *> * _Nullable songs, NSError * _Nullable err))completion;

- (void)searchKeyword:(NSString *)keyword
               source:(NSString *)source
           completion:(void (^)(NSArray<LGSong *> * _Nullable songs, NSError * _Nullable err))completion;

/// 播放控制
- (void)playSong:(LGSong *)song;
- (void)togglePlayPause;
- (void)next;
- (void)previous;
- (void)seekTo:(NSTimeInterval)time;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
