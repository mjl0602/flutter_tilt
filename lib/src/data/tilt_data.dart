import 'package:flutter/widgets.dart';

import '../utils.dart';
import '../enums.dart';
import '../config/tilt_config.dart';

/// 倾斜数据
@immutable
class TiltData {
  /// 倾斜数据
  const TiltData({
    required this.isInit,
    required this.width,
    required this.height,
    required this.areaProgress,
    required this.tiltConfig,
  });

  /// 是否初始化
  final bool isInit;

  /// 尺寸 width
  final double width;

  /// 尺寸 height
  final double height;

  /// 区域进度
  final Offset areaProgress;

  /// 倾斜配置
  final TiltConfig tiltConfig;

  /// 倾斜数据
  TiltDataModel get data => TiltDataModel(
        position: position,
        transform: transform,
        areaProgress: areaProgress,
        angle: angle,
      );

  /// 当前坐标
  Offset get position => progressPosition(width, height, areaProgress);

  /// Transform
  Matrix4 get transform => isInit && !disable
      ? tiltTransform(
          width,
          height,
          areaProgress,
          tiltConfig.angle,
          tiltConfig.enableReverse,
        )
      : Matrix4.identity();

  /// 角度（区分区域）
  ///
  /// {@macro tilt.TiltDataModel.angle}
  Offset get angle =>
      rotateAxis(areaProgress * tiltConfig.angle, tiltConfig.enableReverse);

  /// 禁用
  bool get disable => tiltConfig.disable;
}

/// 倾斜数据
@immutable
class TiltDataModel {
  /// 倾斜数据
  const TiltDataModel({
    required this.position,
    required this.areaProgress,
    required this.transform,
    required this.angle,
  });

  /// 当前坐标
  final Offset position;

  /// 区域进度
  ///
  /// {@template tilt.TiltDataModel.areaProgress}
  /// 正常范围 (x, y)：(1, 1) 至 (-1, -1)
  ///
  /// 移动过程中的最大倾斜量按照 [TiltConfig.angle] 进行倾斜
  ///
  /// 例如：
  /// * (0, 0) 会保持平面
  /// * (1.0, 1.0) 倾斜左上角 [TiltConfig.angle] 最大角度
  /// * (-1.0, -1.0) 倾斜右下角 [TiltConfig.angle] 最大角度
  /// {@endtemplate}
  final Offset areaProgress;

  /// Transform
  final Matrix4 transform;

  /// 角度（区分区域）
  ///
  /// {@template tilt.TiltDataModel.angle}
  /// 正常范围 (x, y)：(angle, angle) 至 (-angle, -angle)
  ///
  /// 移动过程中的最大倾斜量按照 [TiltConfig.angle] 进行倾斜
  ///
  /// 例如：
  /// * (0, 0) 会保持平面
  /// * (angle, angle) 倾斜左上角 [TiltConfig.angle] 最大角度
  /// * (-angle, -angle) 倾斜右下角 [TiltConfig.angle] 最大角度
  /// {@endtemplate}
  final Offset angle;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is TiltDataModel &&
        other.position == position &&
        other.areaProgress == areaProgress &&
        other.transform == transform &&
        other.angle == angle;
  }

  @override
  int get hashCode => Object.hash(
        position.hashCode,
        areaProgress.hashCode,
        transform.hashCode,
        angle.hashCode,
      );
}

/// 倾斜 Stream
@immutable
class TiltStream {
  const TiltStream({
    required this.position,
    required this.gesturesType,
    this.enableRevert,
  });

  /// 当前坐标
  final Offset position;

  final GesturesType gesturesType;

  /// 是否开启复原
  final bool? enableRevert;
}
