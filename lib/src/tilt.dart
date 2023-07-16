import 'dart:async' as async;
import 'package:flutter/widgets.dart';

import 'package:flutter_tilt/src/utils.dart';
import 'package:flutter_tilt/src/type/tilt_type.dart';
import 'package:flutter_tilt/src/type/tilt_light_type.dart';
import 'package:flutter_tilt/src/type/tilt_shadow_type.dart';

import 'package:flutter_tilt/src/tilt_container.dart';
import 'package:flutter_tilt/src/gestures_listener.dart';

import 'package:flutter_tilt/src/state/tilt_state.dart';

class Tilt extends StatefulWidget {
  const Tilt({
    super.key,
    required this.child,
    this.disable = false,
    this.fps = 60,
    this.borderRadius,
    this.clipBehavior = Clip.antiAlias,
    this.tiltConfig = const TiltConfig(),
    this.lightConfig = const LightConfig(),
    this.shadowConfig = const ShadowConfig(),
  });

  final Widget child;

  /// 全部禁用
  final bool disable;

  /// FPS
  ///
  /// 每秒手势触发帧数，帧数越高越平滑，但性能消耗越高。
  ///
  /// 推荐 60 FPS，如果遭遇性能问题，还可以使用人眼能够接受的 24 FPS
  final int fps;

  /// BorderRadius
  final BorderRadiusGeometry? borderRadius;

  /// Clip
  final Clip clipBehavior;

  /// 倾斜配置
  final TiltConfig tiltConfig;

  /// 光源配置
  final LightConfig lightConfig;

  /// 阴影配置
  final ShadowConfig shadowConfig;

  @override
  State<Tilt> createState() => _TiltState();
}

class _TiltState extends State<Tilt> {
  late final Widget _child = widget.child;
  late final bool _disable = widget.disable;
  late final int _fps = widget.fps;
  late final BorderRadiusGeometry? _borderRadius = widget.borderRadius;
  late final Clip _clipBehavior = widget.clipBehavior;
  late final TiltConfig _tiltConfig = widget.tiltConfig;
  late final LightConfig _lightConfig = widget.lightConfig;
  late final ShadowConfig _shadowConfig = widget.shadowConfig;

  /// 是否初始化
  late bool isInit = false;
  late double width = 0.0, height = 0.0;

  /// 当前坐标的区域进度
  late Offset areaProgress = Offset.zero;

  /// 是否正在移动
  late bool isMove = false;

  /// FPS 计时器
  async.Timer? _fpsTimer;

  @override
  Widget build(BuildContext context) {
    if (_disable) {
      return Container(
        decoration: BoxDecoration(borderRadius: _borderRadius),
        clipBehavior: _clipBehavior,
        child: _child,
      );
    }
    return TiltState(
      isInit: isInit,
      width: width,
      height: height,
      areaProgress: areaProgress,
      isMove: isMove,
      onMove: onGesturesMove,
      onRevert: onGesturesRevert,
      onResize: onResize,
      child: GesturesListener(
        tiltConfig: _tiltConfig,
        child: TiltContainer(
          borderRadius: _borderRadius,
          clipBehavior: _clipBehavior,
          tiltConfig: _tiltConfig,
          lightConfig: _lightConfig,
          shadowConfig: _shadowConfig,
          child: _child,
        ),
      ),
    );
  }

  /// 调整尺寸
  void onResize(Size size) {
    if (isInit) return;
    setState(() {
      isInit = true;
      width = size.width;
      height = size.height;
      areaProgress = p2cAreaProgress(
        width,
        height,
        Offset.zero,
        _tiltConfig.direction,
      );
    });
  }

  /// 手势移动触发
  void onGesturesMove(Offset offset) {
    if (!isInit) return;
    if (!fpsTimer()) return;
    if (_tiltConfig.enableOutsideAreaMove || isInRange(width, height, offset)) {
      setState(() {
        areaProgress = p2cAreaProgress(
          width,
          height,
          offset,
          _tiltConfig.direction,
        );
        isMove = true;
      });
    } else {
      onGesturesRevert(offset);
    }
  }

  /// 手势复原触发
  void onGesturesRevert(Offset offset) {
    if (!isInit) return;
    setState(() {
      areaProgress = p2cAreaProgress(
        width,
        height,
        offset,
        _tiltConfig.direction,
      );
      isMove = false;
    });
  }

  /// FPS
  bool fpsTimer() {
    if (_fpsTimer == null) {
      _fpsTimer = async.Timer(
        Duration(milliseconds: (1 / _fps * 1000) ~/ 1),
        () => _fpsTimer = null,
      );
      return true;
    } else {
      return false;
    }
  }
}
