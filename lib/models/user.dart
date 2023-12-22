import 'package:flutter/material.dart';

class AgoraUser {
  int uid;
  bool muted;
  bool videoDisabled;
  String? name;
  Color? backgroundColor;

  AgoraUser({
    required this.uid,
    this.muted = false,
    this.videoDisabled = false,
    this.name,
    this.backgroundColor,
  });


  @override
  bool operator ==(Object other) =>
    identical(this, other) || other is AgoraUser && runtimeType == other.runtimeType && uid == other.uid;

  @override
  // TODO: implement hashCode
  int get hashCode => uid.hashCode;


  AgoraUser copyWith({
    int? uid,
    bool? muted,
    bool? videoDisabled,
    String? name,
    Color? backgroundColor,
}) {
    return AgoraUser(
      uid: uid ?? this.uid,
      muted: muted ?? this.muted,
      videoDisabled: videoDisabled ?? this.videoDisabled,
      name: name ?? this.name,
      backgroundColor:  backgroundColor ?? this.backgroundColor,
    );
  }
}
