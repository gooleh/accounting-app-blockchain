// lib/services/ipfs_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // dotenv 패키지 임포트
import 'package:logger/logger.dart'; // Logger 패키지 임포트

class IPFSService {
  final String apiUrl = 'https://api.pinata.cloud/pinning/pinJSONToIPFS';
  final String pinataApiKey = dotenv.env['PINATA_API_KEY'] ?? '';
  final String pinataSecretApiKey = dotenv.env['PINATA_SECRET_API_KEY'] ?? '';

  final Logger _logger = Logger();

  /// IPFS에 데이터를 업로드하는 함수
  Future<String> uploadData(Map<String, dynamic> data) async {
    // Pinata API는 'pinataContent' 필드 내에 JSON 데이터를 요구합니다.
    final body = jsonEncode({
      'pinataContent': data,
      'pinataOptions': {'cidVersion': 1}
    });

    _logger.d('IPFS 업로드 요청 데이터: $body');

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'pinata_api_key': pinataApiKey,
        'pinata_secret_api_key': pinataSecretApiKey,
      },
      body: body, // 'pinataContent' 포함된 데이터 전송
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final bodyResponse = jsonDecode(response.body);
      _logger.d('IPFS 업로드 성공: ${bodyResponse['IpfsHash']}');
      return bodyResponse['IpfsHash'];
    } else {
      _logger.e('IPFS 업로드 실패: ${response.statusCode} ${response.body}');
      throw Exception('Failed to upload data to IPFS: ${response.body}');
    }
  }

  /// IPFS에서 데이터를 가져오는 함수
  Future<Map<String, dynamic>> fetchData(String cid) async {
    final response = await http.get(
      Uri.parse('https://gateway.pinata.cloud/ipfs/$cid'),
    );

    if (response.statusCode == 200) {
      // 응답 본문을 UTF-8로 디코딩
      final decodedData = utf8.decode(response.bodyBytes);
      _logger.d('Decoded IPFS 데이터: $decodedData'); // 디코딩된 데이터 로그
      return jsonDecode(decodedData);
    } else {
      _logger.e('IPFS 데이터 가져오기 실패: ${response.statusCode} ${response.body}');
      throw Exception('Failed to fetch data from IPFS: ${response.body}');
    }
  }
}
