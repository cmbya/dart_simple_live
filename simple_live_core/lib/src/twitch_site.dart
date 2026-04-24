import 'dart:convert';
import 'package:http/http.dart' as http;
import 'interface/live_site.dart';
import 'model/live_play_url.dart';
import 'model/live_room_detail.dart';
import 'model/live_play_quality.dart';
import 'model/live_category.dart';
import 'model/live_category_result.dart';
import 'model/live_room_item.dart';

// 我们让 TwitchSite 继承 LiveSite 这张说明书
class TwitchSite extends LiveSite {
  @override
  String id = "twitch";

  @override
  String name = "Twitch";

  // 核心功能：获取播放链接
  @override
  Future<LivePlayUrl> getPlayUrls({required LiveRoomDetail detail, required LivePlayQuality quality}) async {
    final roomId = detail.roomId; 
    final gqlUrl = 'https://gql.twitch.tv/gql';
    final clientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko'; 
    
    final body = jsonEncode([{
      "operationName": "PlaybackAccessToken_Template",
      "query": "query PlaybackAccessToken_Template(\$login: String!, \$isLive: Boolean!, \$vodID: ID!, \$isVod: Boolean!, \$playerType: String!) {  streamPlaybackAccessToken(channelName: \$login, params: {platform: \"web\", playerBackend: \"mediaplayer\", playerType: \$playerType}) @include(if: \$isLive) {    value    signature   } }",
      "variables": {
        "isLive": true,
        "login": roomId, 
        "isVod": false,
        "vodID": "",
        "playerType": "site"
      }
    }]);

    final response = await http.post(
      Uri.parse(gqlUrl), 
      headers: {'Client-Id': clientId}, 
      body: body
    );
    
    final data = jsonDecode(response.body)[0]['data']['streamPlaybackAccessToken'];
    final sig = data['signature'];
    final token = data['value'];

    String videoUrl = 'https://usher.ttvnw.net/api/channel/hls/$roomId.m3u8?allow_source=true&sig=$sig&token=$token';
    
    return LivePlayUrl(urls: [videoUrl]);
  }

  // 暂时让其他功能返回空，保证不报错
  @override
  Future<List<LiveCategory>> getCategores() async => [];
  
  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async => 
      LiveCategoryResult(hasMore: false, items: []);
}