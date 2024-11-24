// lib/services/ipfs_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

class IPFSService {
  final String apiUrl = 'https://api.pinata.cloud/pinning/pinJSONToIPFS';
  final String pinataApiKey = dotenv.env['PINATA_API_KEY'] ??
      (throw Exception('PINATA_API_KEY가 설정되지 않았습니다.'));
  final String pinataSecretApiKey = dotenv.env['PINATA_SECRET_API_KEY'] ??
      (throw Exception('PINATA_SECRET_API_KEY가 설정되지 않았습니다.'));

  final Logger _logger = Logger();

  /// IPFS에 데이터를 업로드하는 함수
  Future<String> uploadData(Map<String, dynamic> data) async {
    final body = jsonEncode({
      'pinataContent': data,
      'pinataOptions': {'cidVersion': 1}
    });

    _logger.d('IPFS 업로드 요청 데이터: $data');

    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'pinata_api_key': pinataApiKey,
              'pinata_secret_api_key': pinataSecretApiKey,
            },
            body: body,
          )
          .timeout(Duration(seconds: 15)); // 15초 타임아웃 설정

      if (response.statusCode == 200 || response.statusCode == 201) {
        final bodyResponse = jsonDecode(response.body);
        _logger.d('IPFS 업로드 성공: ${bodyResponse['IpfsHash']}');
        return bodyResponse['IpfsHash'];
      } else {
        _logger.e('IPFS 업로드 실패: ${response.statusCode} ${response.body}');
        throw Exception('IPFS에 데이터를 업로드하는 데 실패했습니다: ${response.body}');
      }
    } catch (e) {
      _logger.e('IPFS 업로드 중 오류 발생: $e');
      rethrow;
    }
  }

  /// IPFS에서 데이터를 가져오는 함수
  Future<Map<String, dynamic>> fetchData(String cid) async {
    int retryCount = 0;
    const maxRetries = 3;
    const initialDelay = Duration(seconds: 2);
    List<String> gateways = [
      'https://ipfs.io/ipfs/',
      'https://cloudflare-ipfs.com/ipfs/',
      'https://gateway.pinata.cloud/ipfs/',
    ];

    while (retryCount < maxRetries) {
      for (String gateway in gateways) {
        try {
          final response = await http
              .get(Uri.parse('$gateway$cid'))
              .timeout(Duration(seconds: 10)); // 10초 타임아웃 설정

          if (response.statusCode == 200) {
            final decodedData = utf8.decode(response.bodyBytes);
            _logger.d('IPFS 데이터 가져오기 성공: $cid');
            return jsonDecode(decodedData);
          } else if (response.statusCode == 429 || response.statusCode == 504) {
            _logger.w(
                '요청 제한 또는 타임아웃 발생 ($gateway). ${initialDelay.inSeconds}초 후 재시도합니다.');
            await Future.delayed(initialDelay);
            retryCount++;
            break; // 현재 게이트웨이에서 실패 시 다음 게이트웨이로 시도
          } else {
            _logger.e(
                'IPFS 데이터 가져오기 실패 ($gateway): ${response.statusCode} ${response.body}');
            throw Exception('IPFS에서 데이터를 가져오는 데 실패했습니다: ${response.body}');
          }
        } catch (e) {
          _logger.e('게이트웨이 $gateway에서 데이터 가져오기 중 오류 발생: $e');
          // 다음 게이트웨이를 시도
        }
      }

      // 지수 백오프 적용
      await Future.delayed(initialDelay * (retryCount + 1));
      retryCount++;
    }

    throw Exception('모든 게이트웨이에서 $maxRetries 번 시도했지만 IPFS 데이터를 가져오지 못했습니다.');
  }
}
