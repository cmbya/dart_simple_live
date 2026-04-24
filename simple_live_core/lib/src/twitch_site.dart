import 'dart:convert';
import 'package:http/http.dart' as http;

import 'interface/live_site.dart';
import 'model/live_category.dart';
import 'model/live_category_result.dart';
import 'model/live_play_quality.dart';
import 'model/live_play_url.dart';
import 'model/live_room_detail.dart';
import 'model/live_room_item.dart';

class TwitchSite extends LiveSite {
  @override
  String id = "twitch";

  @override
  String name = "Twitch";

  final String _gqlUrl = 'https://gql.twitch.tv/gql';
  final String _clientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';

  Future<dynamic> _postGql(Map<String, dynamic> query) async {
    final response = await http.post(
      Uri.parse(_gqlUrl),
      headers: {'Client-Id': _clientId},
      body: jsonEncode([query]), 
    );
    return jsonDecode(response.body)[0]['data'];
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async {
    final query = {
      "query": "query { streams(first: 30) { edges { node { broadcaster { login displayName } title viewersCount previewImageURL(width: 320, height: 180) } } } }"
    };
    final data = await _postGql(query);
    List<LiveRoomItem> items = [];
    
    for (var edge in data['streams']['edges']) {
      var node = edge['node'];
      var bc = node['broadcaster'];
      items.add(LiveRoomItem(
        roomId: bc['login'],
        title: node['title'],
        userName: bc['displayName'],
        cover: node['previewImageURL'],
        online: node['viewersCount'],
        // 修复：去掉了不支持的 userAvatar
      ));
    }
    return LiveCategoryResult(hasMore: false, items: items);
  }

  @override
  Future<List<LiveCategory>> getCategores() async {
    final query = {
      "query": "query { directoriesWithTags(first: 20) { edges { node { id name avatarURL(width: 144, height: 192) } } } }"
    };
    final data = await _postGql(query);
    
    // 修复：添加了 required 的 children 参数
    LiveCategory mainCategory = LiveCategory(id: "all", name: "热门分类", children: []);

    for (var edge in data['directoriesWithTags']['edges']) {
      var node = edge['node'];
      // 修复：改用 children.add
      mainCategory.children.add(LiveSubCategory(
        id: node['name'], 
        name: node['name'],
        pic: node['avatarURL'],
        parentId: "all",
      ));
    }
    return [mainCategory];
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveSubCategory category, {int page = 1}) async {
    final query = {
      "query": "query(\$game: String!) { game(name: \$game) { streams(first: 30) { edges { node { broadcaster { login displayName } title viewersCount previewImageURL(width: 320, height: 180) } } } } }",
      "variables": {"game": category.name}
    };
    final data = await _postGql(query);
    List<LiveRoomItem> items = [];
    
    if (data['game'] != null && data['game']['streams'] != null) {
      for (var edge in data['game']['streams']['edges']) {
        var node = edge['node'];
        var bc = node['broadcaster'];
        items.add(LiveRoomItem(
          roomId: bc['login'],
          title: node['title'],
          userName: bc['displayName'],
          cover: node['previewImageURL'],
          online: node['viewersCount'],
          // 修复：去掉了不支持的 userAvatar
        ));
      }
    }
    return LiveCategoryResult(hasMore: false, items: items);
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    final query = {
      "query": "query(\$login: String!) { user(login: \$login) { stream { id } } }",
      "variables": {"login": roomId}
    };
    final data = await _postGql(query);
    return data['user'] != null && data['user']['stream'] != null;
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    final query = {
      "query": "query(\$login: String!) { user(login: \$login) { displayName profileImageURL(width: 50) stream { title viewersCount } } }",
      "variables": {"login": roomId}
    };
    final data = await _postGql(query);
    var user = data['user'];
    bool isLive = user != null && user['stream'] != null;

    return LiveRoomDetail(
      roomId: roomId,
      title: isLive ? user['stream']['title'] : '未开播 / 离线',
      userName: user != null ? user['displayName'] : roomId,
      cover: '',
      status: isLive,
      online: isLive ? user['stream']['viewersCount'] : 0,
      url: 'https://www.twitch.tv/$roomId',
      userAvatar: user != null ? user['profileImageURL'] : '', // LiveRoomDetail 里是允许有这个的，保留
    );
  }

  @override
  Future<LivePlayUrl> getPlayUrls({required LiveRoomDetail detail, required LivePlayQuality quality}) async {
    final roomId = detail.roomId;
    final body = {
      "operationName": "PlaybackAccessToken_Template",
      "query": "query PlaybackAccessToken_Template(\$login: String!, \$isLive: Boolean!, \$vodID: ID!, \$isVod: Boolean!, \$playerType: String!) {  streamPlaybackAccessToken(channelName: \$login, params: {platform: \"web\", playerBackend: \"mediaplayer\", playerType: \$playerType}) @include(if: \$isLive) {    value    signature   } }",
      "variables": {
        "isLive": true,
        "login": roomId,
        "isVod": false,
        "vodID": "",
        "playerType": "site"
      }
    };
    
    final tokenData = await _postGql(body);
    final data = tokenData['streamPlaybackAccessToken'];
    final sig = data['signature'];
    final token = data['value'];

    String videoUrl = 'https://usher.ttvnw.net/api/channel/hls/$roomId.m3u8?allow_source=true&sig=$sig&token=$token';
    return LivePlayUrl(urls: [videoUrl]);
  }
  
  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoomDetail detail}) async {
    return [LivePlayQuality(quality: '原画(Twitch 自适应)', sort: 10000)];
  }
}