import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'enums.dart';
import 'config/tilt_config.dart';

/// 传感器平台支持
bool sensorsPlatformSupport() {
  bool support = false;
  if (kIsWeb) return support = true;
  if (Platform.isAndroid) support = true;
  if (Platform.isIOS) support = true;
  return support;
}

/// 区域中心定位
///
/// [width], [height] 区域尺寸
Offset centerPosition(double width, double height) => Offset(width, height) / 2;

/// 弧度
double radian(double angle) => pi / 180.0 * angle;

/// 两点间的距离 sqrt((x1-x2)²+(y1-y2)²)
///
/// 坐标 (x1, y1) 到坐标 (x2, y2) 的距离
double p2pDistance(Offset p1, Offset p2) {
  final double x1 = p1.dx, y1 = p1.dy;
  final double x2 = p2.dx, y2 = p2.dy;
  return sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
}

/// 计算当前坐标进度的倾斜
///
/// * [width], [height] 区域尺寸
/// * [areaProgress] 当前坐标的区域进度
/// * [angle] 可旋转角度，为 0 将会停止不动
/// * [enableReverse] 开启倾斜反向，向上或向下倾斜
Matrix4 tiltTransform(
  double width,
  double height,
  Offset areaProgress,
  double angle,
  bool enableReverse,
) {
  /// 旋转大小：区域进度 * 弧度
  final Offset rotate = rotateAxis(areaProgress * radian(angle), enableReverse);
  final double rotateX = rotate.dx, rotateY = rotate.dy;

  return Matrix4.identity()

    /// 近大远小效果（适配不同尺寸的组件）
    ..setEntry(3, 2, 0.5 / (width > height ? width : height))

    /// 旋转轴
    ..rotateX(rotateX)
    ..rotateY(rotateY);
}

/// 旋转轴
///
/// * [rotate] 旋转大小
/// * [enableReverse] 反向
Offset rotateAxis(Offset rotate, bool enableReverse) => enableReverse
    ? Offset(-rotate.dy, rotate.dx)
    : Offset(rotate.dy, -rotate.dx);

/// 计算当前坐标相对于中心坐标的区域坐标
///
/// PositionToCenterAreaPosition
///
/// 可以定位当前坐标正处于的区域方向，以及区域内的坐标位置
///
/// [width], [height] 区域尺寸
///
/// [position] 当前坐标定位
///
/// (x, y) = (0, 0) 为中心点
///
/// (x, y) 区域坐标范围：(width / 2, height / 2) 到 (-width / 2, -height / 2)
///
/// 如果值超出了区域坐标范围，那么代表这个坐标不在区域内
Offset p2cAreaPosition(double width, double height, Offset position) {
  final Offset center = centerPosition(width, height);
  late double x = center.dx - position.dx;
  late double y = center.dy - position.dy;

  final double centerWidth = width / 2.0;
  final double centerHeight = height / 2.0;

  /// 限制最大值
  if (x > centerWidth) x = centerWidth;
  if (x < -centerWidth) x = -centerWidth;
  if (y > centerHeight) y = centerHeight;
  if (y < -centerHeight) y = -centerHeight;

  return Offset(x, y);
}

/// 计算当前坐标在中心坐标到区域边界的进度
///
/// PositionToCenterAreaProgress
///
/// 可以定位当前坐标正处于的区域方向，以及区域内到边界的进度
///
/// * [width], [height] 区域尺寸
/// * [position] 当前坐标定位
/// * [tiltDirection] 倾斜方向限制
///
/// (x, y) = (0, 0) 为中心点
///
/// (x, y) 区域进度范围：(1, 1) 到 (-1,-1)
///
/// 如果值超出了区域进度范围，那么代表这个坐标不在区域内，比如 (1.1, 1), (-1, 1.1)
Offset p2cAreaProgress(
  double width,
  double height,
  Offset position,
  List<TiltDirection>? tiltDirection,
) {
  if (width == 0.0 || height == 0.0) return Offset.zero;
  final Offset center = centerPosition(width, height);
  late double x = (center.dx - position.dx) / width * 2.0;
  late double y = (center.dy - position.dy) / height * 2.0;
  final List<TiltDirection> tiltDirectionList = <TiltDirection>[
    ...?tiltDirection,
  ];

  /// 限制最大值
  if (x > 1.0) x = 1.0;
  if (x < -1.0) x = -1.0;
  if (y > 1.0) y = 1.0;
  if (y < -1.0) y = -1.0;

  /// 限制倾斜方向
  if (tiltDirectionList.isNotEmpty) {
    final TiltDirection direction = TiltDirection.validator(
      TiltDirection(x, y),
      tiltDirectionList,
    );
    x = direction.dx;
    y = direction.dy;
  }

  return Offset(x, y);
}

/// 通过 [p2cAreaProgress] 的进度，获得当前坐标位置
///
Offset progressPosition(double width, double height, Offset areaProgress) {
  if (width == 0.0 || height == 0.0) return Offset.zero;
  return Offset(
    width / 2.0 * (1.0 - areaProgress.dx),
    height / 2.0 * (1.0 - areaProgress.dy),
  );
}

/// 计算提供的方向进度
///
/// 范围：0-1
///
/// * [width], [height] 区域尺寸
/// * [areaProgress] 当前坐标的区域进度
/// * [direction] 方向计算方式
///   * [LightDirection] 光线方向
///   * [ShadowDirection] 阴影方向
///
/// 可选项
/// * [min] 最小进度限制 0-1
/// * [max] 最大进度限制 0-1
/// * [enableReverse] 开启反向
///
double directionProgress<T>(
  Offset areaProgress,
  T direction, {
  double min = 0.0,
  double max = 1.0,
  bool enableReverse = false,
}) {
  assert(min <= max && min >= 0.0 && max <= 1.0);

  /// 区域进度
  final Offset progress = -areaProgress;
  final double progressX = progress.dx, progressY = progress.dy;

  /// 区域进度
  late double dataX = progressX, dataY = progressY;

  /// 距离中心
  final double dataDistance = p2pDistance(Offset.zero, Offset(dataX, dataY));

  /// 限制距离中心
  final double constraintsDistance = dataDistance > max ? max : dataDistance;

  /// 进度
  late double progressData = min;

  /// 光源方向计算方式
  if (direction.runtimeType == LightDirection) {
    switch (direction as LightDirection) {
      case LightDirection.none:
        break;
      case LightDirection.around:
        final double distance = constraintsDistance;
        progressData = distance;
        break;
      case LightDirection.all:
        progressData = max;
        break;
      case LightDirection.top:
        progressData = progressY;
        break;
      case LightDirection.bottom:
        progressData = -progressY;
        break;
      case LightDirection.left:
        progressData = progressX;
        break;
      case LightDirection.right:
        progressData = -progressX;
        break;
      case LightDirection.center:
        final double distance = constraintsDistance;
        progressData = max - distance;
        break;
      case LightDirection.topLeft:
        progressData = progressX + progressY;
        break;
      case LightDirection.bottomRight:
        progressData = -(progressX + progressY);
        break;
      case LightDirection.topRight:
        progressData = -(progressX - progressY);
        break;
      case LightDirection.bottomLeft:
        progressData = progressX - progressY;
        break;
      case LightDirection.xCenter:
        if (progressY < 0.0) dataY = -progressY;
        progressData = max - dataY;
        break;
      case LightDirection.yCenter:
        if (progressX < 0.0) dataX = -progressX;
        progressData = max - dataX;
        break;
    }
  }

  /// 阴影方向计算方式
  if (direction.runtimeType == ShadowDirection) {
    switch (direction as ShadowDirection) {
      case ShadowDirection.none:
        break;
      case ShadowDirection.around:
        final double distance = constraintsDistance;
        progressData = distance;
        break;
      case ShadowDirection.all:
        progressData = max;
        break;
      case ShadowDirection.top:
        progressData = -progressY;
        break;
      case ShadowDirection.bottom:
        progressData = progressY;
        break;
      case ShadowDirection.left:
        progressData = -progressX;
        break;
      case ShadowDirection.right:
        progressData = progressX;
        break;
      case ShadowDirection.center:
        final double distance = constraintsDistance;
        progressData = max - distance;
        break;
      case ShadowDirection.topLeft:
        progressData = -(progressX + progressY);
        break;
      case ShadowDirection.bottomRight:
        progressData = progressX + progressY;
        break;
      case ShadowDirection.topRight:
        progressData = progressX - progressY;
        break;
      case ShadowDirection.bottomLeft:
        progressData = -(progressX - progressY);
        break;
      case ShadowDirection.xCenter:
        if (progressY < 0.0) dataY = -progressY;
        progressData = max - dataY;
        break;
      case ShadowDirection.yCenter:
        if (progressX < 0.0) dataX = -progressX;
        progressData = max - dataX;
        break;
    }
  }

  /// 强度
  progressData = progressData * max;

  /// 反向
  if (enableReverse) progressData = -progressData;

  /// 避免超出范围
  if (progressData < min) progressData = min;
  if (progressData > max) progressData = max;

  return progressData;
}

/// 计算坐标是否在区域内
///
/// [width], [height] 区域尺寸
///
/// [position] 当前坐标定位
bool isInRange(double width, double height, Offset position) {
  final double x = position.dx, y = position.dy;
  return x <= width && x >= 0.0 && y <= height && y >= 0.0;
}

/// 限制区域尺寸定位
///
/// * [width], [height] 区域尺寸
/// * [position] 需要限制的定位
Offset constraintsPosition(double width, double height, Offset position) {
  late double constraintWidth = position.dx;
  late double constraintHidth = position.dy;

  if (constraintWidth > width) constraintWidth = width;
  if (constraintWidth < 0) constraintWidth = 0;
  if (constraintHidth > height) constraintHidth = height;
  if (constraintHidth < 0) constraintHidth = 0;

  return Offset(constraintWidth, constraintHidth);
}

/// Tilt TweenAnimation End
/// - [isMove] 是否移动
/// - [tiltConfig] TiltConfig
/// - [areaProgress] 当前进度
Offset tiltTweenAnimationEnd(
  bool isMove,
  TiltConfig tiltConfig,
  Offset areaProgress,
) =>
    isMove || !tiltConfig.enableRevert
        ? areaProgress
        : (tiltConfig.initial ?? Offset.zero);

/// Tilt TweenAnimation Duration
/// - [isMove] 是否移动
/// - [currentGesturesType] 当前手势类型
/// - [tiltConfig] TiltConfig
Duration tiltTweenAnimationDuration(
  bool isMove,
  GesturesType currentGesturesType,
  TiltConfig tiltConfig,
) {
  late Duration duration;
  switch (currentGesturesType) {
    case GesturesType.none:
      duration = Duration.zero;
      break;
    case GesturesType.touch:
      duration = isMove ? tiltConfig.moveDuration : tiltConfig.leaveDuration;
      break;
    case GesturesType.hover:
      duration = isMove ? tiltConfig.moveDuration : tiltConfig.leaveDuration;
      break;
    case GesturesType.sensors:
      duration = tiltConfig.sensorMoveDuration;
      break;
  }
  return duration;
}

/// Tilt TweenAnimation Curve
/// - [isMove] 是否移动
/// - [currentGesturesType] 当前手势类型
/// - [tiltConfig] TiltConfig
Curve tiltTweenAnimationCurve(
  bool isMove,
  GesturesType currentGesturesType,
  TiltConfig tiltConfig,
) {
  late Curve curve;
  switch (currentGesturesType) {
    case GesturesType.none:
      curve = Curves.linear;
      break;
    case GesturesType.touch:
      curve = isMove ? tiltConfig.moveCurve : tiltConfig.leaveCurve;
      break;
    case GesturesType.hover:
      curve = isMove ? tiltConfig.moveCurve : tiltConfig.leaveCurve;
      break;
    case GesturesType.sensors:
      curve = Curves.linear;
      break;
  }
  return curve;
}
