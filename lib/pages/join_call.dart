import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:agora_token_service/agora_token_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/user.dart';
import '../utils/app_id.dart';
import '../utils/message.dart';

class JoinCall extends StatefulWidget {
  const JoinCall(
      {super.key,
      required this.channelName,
      required this.userName,
      required this.uid});

  final int uid;
  final String channelName;
  final String userName;

  @override
  State<JoinCall> createState() => _JoinCallState();
}

class _JoinCallState extends State<JoinCall> {
  List<AgoraUser> _users = [];
  String rtcToken = '';
  int? _remoteUid;
  bool _isJoined = false;
  bool localUserActive = false;
  late RtcEngine _engine;
  AgoraRtmClient? _client;
  AgoraRtmChannel? _channel;
  bool muted = false;
  bool videoDisabled = false;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    initializeAgora();
    generateToken();
    setupVideoSDKEngine();
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    // _isJoined = false;
    // _remoteUid = null;
    _engine.release();
    _channel?.leave();
    _client?.logout();
    _client?.release();
    _users.clear();

    super.dispose();
  }

  showMessage(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(message),
    ));
  }

  Future<void> setupVideoSDKEngine() async {
    // retrieve or request camera and microphone permissions
    await [Permission.microphone, Permission.camera].request();

    //create an instance of the Agora engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(appId: appId));

    await _engine.enableVideo();

    // Register the event handler
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          showMessage(
              "Local user uid:${connection.localUid} joined the channel");
          // setState(() {
          //   _isJoined = true;
          // });
          print('registerEvent : onjoinsuccess ${connection.localUid}');
          setState(() {
            _users.add(AgoraUser(uid: connection.localUid!));
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          showMessage("Remote user uid:$remoteUid joined the channel");
          // setState(() {
          //   _remoteUid = remoteUid;
          // });
          print('registerEvent : userjoined ${connection.localUid}');
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          showMessage("Remote user uid:$remoteUid left the channel");
          // setState(() {
          //   _remoteUid = null;
          // });
          print('registerEvent : userOffline ${connection.localUid}');
        },
      ),
    );

    ChannelMediaOptions options;
    options = const ChannelMediaOptions(
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    );
    await _engine.startPreview();
    // await generateToken();
    await _engine.joinChannel(
      token: rtcToken,
      channelId: widget.channelName,
      options: options,
      uid: widget.uid,
    );
  }

  Future<void> initializeAgora() async {
    _engine = createAgoraRtcEngine();

    await _engine.initialize(const RtcEngineContext(
      appId: appId,
    ));
    // await _engine.initialize(
    //   const RtcEngineContext(
    //     appId: appId,
    //   ),
    // );
    _client = await AgoraRtmClient.createInstance(appId);
    // await getToken(sessionController: SessionController());
    await _engine.enableVideo();
    // await _engine.enableAudio();
    await _engine
        .setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    // await _engine.setupLocalVideo(
    //   VideoCanvas(
    //     view: 1,
    //     uid: widget.uid,
    //     renderMode: RenderModeType.renderModeFit,
    //   ),
    // );

    //Callbacks for the RTC engine

    //Callbacks for the RTC Engine
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onError: (ErrorCodeType err, String msg) async {
          print('[....onError] err: $err, ,msg:$msg');
        },
        onJoinChannelSuccess: (RtcConnection rtcConn, int elapsed) {
          //TODO: Add join channel logic
          print('....onConnection ${rtcConn.toJson()}');
          print('${rtcConn.localUid} && ${rtcConn.channelId} && $elapsed');
          setState(() {
            print('local uid: ${rtcConn.localUid}');
            _users.add(AgoraUser(uid: rtcConn.localUid as int));
            // int randomColor = (Random().nextDouble() *0xFFFFFFFF).toInt();

            // _client!.addOrUpdateLocalUserAttributes2([RtmAttribute('name', widget.userName), RtmAttribute('color', randomColor.toString())]);
          });
        },
        onUserJoined:
            (RtcConnection rtcConn, int remoteUid, int elasped) async {
          print('....onConnection _remoteUid $remoteUid');
          setState(() {
            _remoteUid = remoteUid;
            _isJoined = true;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          print('....onUserOffline $remoteUid');
          setState(() {
            _remoteUid = null;
            _isJoined = false;
            print('....onUserOffline remoteUid is $_remoteUid');
          });
        },
        onLeaveChannel: (RtcConnection rtcConn, RtcStats stats) {
          setState(() {
            print('....onLeaveChannel');
            _users.clear();
            _isJoined = false;
            _remoteUid = null;
            print('....onLeaveChannel remoteUid is $_remoteUid');
          });
        },
        onRtcStats: (RtcConnection connection, RtcStats stats) {
          // print("time....");
          // print(stats.duration);
        },
      ),
    );

    //Callbacks for the RTM client
    _client?.onMessageReceived = (RtmMessage message, String peerId) {
      print('Private Message from $peerId : ${message.text}');
    };

    _client?.onConnectionStateChanged2 =
        (RtmConnectionState state, RtmConnectionChangeReason reason) {
      print(
          'Connection state change ${state.toString()}, reason: ${reason.toString()}');
      if (state == 5) {
        _channel?.leave();
        _client?.logout();
        _client?.release();
        print('Logged out.');
      }
    };

    //join the RTM and RTC channels
    try {
      await _client?.login(null, widget.uid.toString());
      print('try client login');
    } catch (e) {
      print('catch client login\n${e.toString()}');
    }
    _channel = await _client?.createChannel(widget.channelName);
    await _channel?.join();
    // await generateToken();
    await _engine.joinChannel(
      token: rtcToken,
      channelId: widget.channelName,
      uid: widget.uid,
      options: const ChannelMediaOptions(
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
      ),
    );
    // try {
    //   // await _client?.release();
    //   // await _client?.login(token, widget.uid.toString());
    //   // _channel = await _client?.createChannel(widget.channelName);
    //   // VideoEncoderConfiguration configuration = const VideoEncoderConfiguration();
    //   // await _engine.setVideoEncoderConfiguration(configuration);
    //   // // await _engine.leaveChannel();
    //   // await _channel?.join();
    //   await _engine.joinChannel(
    //     token: token,
    //     channelId: widget.channelName,
    //     uid: widget.uid,
    //     options: const ChannelMediaOptions(),
    //   );
    //   // await _engine.startPreview();
    // } catch (e) {
    //   print('catch error: $e');
    // }

    //Callbacks for the RTM channel
    _channel?.onMemberJoined = (RtmChannelMember member) {
      print('Member joined: ${member.userId} , channel: ${member.channelId}');
    };
    _channel?.onMemberLeft = (RtmChannelMember member) {
      print('Member joined: ${member.userId} , channel: ${member.channelId}');
    };
    _channel?.onMessageReceived = (RtmMessage msg, RtmChannelMember member) {
      //TODO: implement this
      List<String> parsedMessage = msg.text.split(" ");
      switch (parsedMessage[0]) {
        case "mute":
          if (parsedMessage[1] == widget.uid.toString()) {
            setState(() {
              muted = true;
            });
            _engine.muteLocalAudioStream(true);
          }
          break;
        case "unmute":
          if (parsedMessage[1] == widget.uid.toString()) {
            setState(() {
              muted = false;
            });
            _engine.muteLocalAudioStream(false);
          }
          break;
        case "disable":
          if (parsedMessage[1] == widget.uid.toString()) {
            setState(() {
              videoDisabled = true;
            });
            _engine.muteLocalVideoStream(true);
          }
          break;
        case "enable":
          if (parsedMessage[1] == widget.uid.toString()) {
            setState(() {
              videoDisabled = true;
            });
            _engine.muteLocalVideoStream(true);
          }
          break;
        case "activeUser":
          setState(() {
            _users = Message().parseActiveUsers(uids: parsedMessage[1]);
          });
          break;
        default:
      }
      print('Public Message from ${member.userId} : ${msg.text}');
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Stack(
          children: [
            ListView(
              children: <Widget>[
                Container(
                  margin:
                      const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0),
                  height: MediaQuery.of(context).size.height * 0.4,
                  // decoration: BoxDecoration(border: Border.all()),
                  child: Center(child: _broadCastView1()),
                ),
                const SizedBox(height: 10),
                //Container for the Remote video
                Container(
                  margin:
                      const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 3.0),
                  height: MediaQuery.of(context).size.height * 0.4,
                  // decoration: BoxDecoration(border: Border.all()),
                  child: Center(child: _remoteVideo()),
                ),
              ],
            ),
            // _broadcastView(),
            _toolBar(),
          ],
        ),
      ),
    );
  }

  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine,
            canvas: VideoCanvas(uid: _remoteUid),
            connection: RtcConnection(channelId: widget.channelName),
            // useFlutterTexture: true,
            useAndroidSurfaceView: true,
          ),
        ),
      );
    } else {
      String msg = '';
      if (!_isJoined) msg = 'Waiting for a remote user to join';
      return ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: Container(
          color: Colors.blueAccent.withOpacity(0.3),
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const CupertinoActivityIndicator(),
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.01,
                ),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _broadCastView1() {
    localUserActive = _users.isNotEmpty ? true : false;
    if (_users.isEmpty) {
      print('No User');
      return const Center(
        child: CupertinoActivityIndicator(),
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: Row(
          children: [
            Expanded(
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _engine,
                  canvas: VideoCanvas(uid: 0),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _toolBar() {
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          localUserActive
              ? RawMaterialButton(
                  onPressed: _onToggleMute,
                  child: Icon(
                    muted ? Icons.mic_off : Icons.mic,
                    color: muted ? Colors.white : Colors.blueAccent,
                    size: 20.0,
                  ),
                  shape: CircleBorder(),
                  elevation: 2.0,
                  fillColor: muted ? Colors.blueAccent : Colors.white,
                  padding: const EdgeInsets.all(12.0),
                )
              : SizedBox(),
          RawMaterialButton(
            onPressed: () => _onCallEnd(context),
            child: Icon(
              Icons.call_end,
              color: Colors.white,
              size: 35.0,
            ),
            shape: CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.redAccent,
            padding: const EdgeInsets.all(15.0),
          ),
          localUserActive
              ? RawMaterialButton(
                  onPressed: _onToggleVideoDisable,
                  child: Icon(
                    videoDisabled ? Icons.videocam_off : Icons.videocam,
                    color: videoDisabled ? Colors.white : Colors.blueAccent,
                    size: 20.0,
                  ),
                  shape: CircleBorder(),
                  elevation: 2.0,
                  fillColor: videoDisabled ? Colors.blueAccent : Colors.white,
                  padding: const EdgeInsets.all(12.0),
                )
              : SizedBox(),
          localUserActive
              ? RawMaterialButton(
                  onPressed: _onSwitchCamera,
                  child: Icon(
                    Icons.switch_camera,
                    color: Colors.blueAccent,
                    size: 20.0,
                  ),
                  shape: CircleBorder(),
                  elevation: 2.0,
                  fillColor: Colors.white,
                  padding: const EdgeInsets.all(12.0),
                )
              : SizedBox(),
        ],
      ),
    );
  }

  /// Helper function to get list of native views
  List<Widget> _getRenderViews() {
    final List<Widget> list = [];
    bool checkIfLocalActive = false;
    print('_users.length : ${_users.length}');
    List<AgoraUser> tempUser = _users;
    Set<AgoraUser> tempSet = Set<AgoraUser>.from(tempUser);
    List<AgoraUser> filteredUser = tempSet.toList();
    print('filteredUser.length : ${filteredUser.length}');
    for (int i = 0; i < filteredUser.length; i++) {
      if (_users[i].uid == widget.uid) {
        list.add(Stack(children: [
          AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _engine,
              canvas: VideoCanvas(uid: 0),
            ),
          ),
          Align(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(10)),
                  color: Colors.white),
              child: Text(widget.userName),
            ),
            alignment: Alignment.bottomRight,
          ),
        ]));
        checkIfLocalActive = true;
      } else {
        list.add(Stack(children: [
          AgoraVideoView(
            controller: VideoViewController.remote(
              connection: RtcConnection(channelId: widget.channelName),
              // useFlutterTexture: true,
              useAndroidSurfaceView: true,
              rtcEngine: _engine,
              canvas: VideoCanvas(uid: _users[i].uid),
            ),
          ),
          Align(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(10)),
                  color: Colors.white),
              child: Text(_users[i].name ?? "name error"),
            ),
            alignment: Alignment.bottomRight,
          ),
        ]));
      }
    }

    if (checkIfLocalActive) {
      localUserActive = true;
    } else {
      localUserActive = false;
    }

    return list;
  }

  /// Video view row wrapper
  Widget _expandedVideoView(List<Widget> views) {
    final wrappedViews = views
        .map<Widget>((view) => Expanded(child: Container(child: view)))
        .toList();
    return Expanded(
      child: Row(
        children: wrappedViews,
      ),
    );
  }

  /// Video layout wrapper
  Widget _broadcastView() {
    final views = _getRenderViews();
    print('views.length : ${views.length}');
    switch (views.length) {
      case 1:
        return Container(
            child: Column(
          children: <Widget>[
            _expandedVideoView([views[0]])
          ],
        ));
      case 2:
        return Container(
            child: Column(
          children: <Widget>[
            _expandedVideoView([views[0]]),
            _expandedVideoView([views[1]])
          ],
        ));
      case 3:
        return Container(
            child: Column(
          children: <Widget>[
            _expandedVideoView(views.sublist(0, 2)),
            _expandedVideoView(views.sublist(2, 3))
          ],
        ));
      case 4:
        return Container(
            child: Column(
          children: <Widget>[
            _expandedVideoView(views.sublist(0, 2)),
            _expandedVideoView(views.sublist(2, 4))
          ],
        ));
      default:
    }
    return Container();
  }

  void _onToggleMute() {
    setState(() {
      muted = !muted;
    });
    _engine.muteLocalAudioStream(muted);
  }

  void _onToggleVideoDisable() {
    setState(() {
      videoDisabled = !videoDisabled;
    });
    _engine.muteLocalVideoStream(videoDisabled);
  }

  void _onSwitchCamera() {
    _engine.switchCamera();
  }

  void _onCallEnd(BuildContext context) {
    Navigator.pop(context);
  }

  Future<void> generateToken() async {
    var today = DateTime.now().add(const Duration(days: 2));
    rtcToken = RtcTokenBuilder.build(
        appId: appId,
        appCertificate: appCerti,
        channelName: widget.channelName,
        uid: widget.uid.toString(),
        role: RtcRole.publisher,
        expireTimestamp: today.millisecondsSinceEpoch);
    print('token : $rtcToken');
  }
}
