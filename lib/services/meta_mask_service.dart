import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import '../services/navigation_service.dart';

class MetaMaskService with ChangeNotifier {
  late Web3App _web3app;
  SessionData? _session;
  final Logger _logger = Logger();

  // 세션 상태를 브로드캐스트하기 위한 StreamController<bool>
  final StreamController<bool> _sessionController =
      StreamController<bool>.broadcast();

  // 외부에서 세션 스트림을 구독할 수 있도록 노출
  Stream<bool> get sessionStream => _sessionController.stream;

  MetaMaskService() {
    _initializeWalletConnect();
  }

  Future<void> _initializeWalletConnect() async {
    const String projectId =
        'daacee7d0e81d87acf6ac2e7e9ba38a9'; // 실제 프로젝트 ID로 변경
    const String relayUrl = 'wss://relay.walletconnect.com';

    try {
      _web3app = await Web3App.createInstance(
        projectId: projectId,
        relayUrl: relayUrl,
        metadata: const PairingMetadata(
          name: 'Accounting App',
          description: 'An accounting application integrated with MetaMask',
          url: 'https://your.app.url',
          icons: ['https://your.app.icon.url/icon.png'],
        ),
      );

      // 이벤트 핸들러 설정
      _web3app.onSessionConnect.subscribe(_onSessionConnect);
      _web3app.onSessionDelete.subscribe(_onSessionDelete);

      _logger.d('WalletConnect 초기화 완료');
    } catch (e) {
      _logger.e('WalletConnect 초기화 오류: $e');
    }
  }

  // 세션 연결 이벤트 핸들러
  void _onSessionConnect(SessionConnect? event) {
    if (event != null) {
      _logger.d('Connected: ${event.session.topic}');
      _session = event.session;
      _sessionController.add(true); // 세션 연결됨을 브로드캐스트
      notifyListeners();
    }
  }

  // 세션 삭제 이벤트 핸들러
  void _onSessionDelete(SessionDelete? event) {
    if (event != null) {
      _logger.d('Disconnected: ${event.topic}');
      _session = null;
      _sessionController.add(false); // 세션 해제됨을 브로드캐스트
      notifyListeners();
    }
  }

  Future<void> connect() async {
    if (_session != null) {
      _logger.d('이미 연결되어 있습니다.');
      return;
    }

    final requiredNamespaces = {
      'eip155': const RequiredNamespace(
        methods: ['eth_sendTransaction', 'personal_sign', 'eth_signTypedData'],
        chains: ['eip155:11155111'], // Sepolia 테스트넷 체인 ID
        events: ['accountsChanged', 'chainChanged'],
      ),
    };

    try {
      // 세션 요청 생성
      final ConnectResponse response = await _web3app
          .connect(
        requiredNamespaces: requiredNamespaces,
      )
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw TimeoutException('연결 시간 초과');
      });

      // 연결 URI 가져오기
      final Uri? uri = response.uri;

      if (uri != null) {
        String deepLinkUrl;

        if (Platform.isAndroid) {
          deepLinkUrl =
              'https://metamask.app.link/wc?uri=${Uri.encodeComponent(uri.toString())}';
        } else if (Platform.isIOS) {
          deepLinkUrl =
              'metamask://wc?uri=${Uri.encodeComponent(uri.toString())}';
        } else {
          _logger.e('지원되지 않는 플랫폼입니다.');
          return;
        }

        _logger.d('Deep Link URL: $deepLinkUrl');

        if (await canLaunchUrl(Uri.parse(deepLinkUrl))) {
          await launchUrl(Uri.parse(deepLinkUrl),
              mode: LaunchMode.externalApplication);
        } else {
          _logger.e('$deepLinkUrl 을(를) 실행할 수 없습니다.');

          // MetaMask 앱이 설치되어 있지 않을 경우 알림 표시
          _showMetaMaskNotInstalledAlert();
        }
      } else {
        _logger.e('연결 URI를 가져올 수 없습니다.');
      }
    } on TimeoutException catch (e) {
      _logger.e('연결 시간 초과: $e');
      // 연결 시간 초과 알림 표시
      _showConnectionTimeoutAlert();
    } catch (e) {
      _logger.e('연결 중 오류 발생: $e');
    }
  }

  Future<void> disconnect() async {
    if (_session != null) {
      await _web3app.disconnectSession(
        topic: _session!.topic,
        reason: Errors.getSdkError(Errors.USER_DISCONNECTED),
      );
      _logger.d('세션 연결 해제: ${_session!.topic}');
      _session = null;
      _sessionController.add(false); // 세션 해제됨을 브로드캐스트
      notifyListeners();
    } else {
      _logger.d('연결된 세션이 없습니다.');
    }
  }

  String get walletAddress {
    if (_session != null) {
      final accounts = _session!.namespaces['eip155']?.accounts;
      if (accounts != null && accounts.isNotEmpty) {
        // 계정 형식: 'eip155:11155111:0xabc...'
        return accounts.first.split(':').last;
      }
    }
    return '';
  }

  bool get isConnected => _session != null;

  void _showMetaMaskNotInstalledAlert() {
    final BuildContext? context =
        NavigationService.navigatorKey.currentState?.context;
    if (context != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('MetaMask 앱 필요'),
            content: const Text('MetaMask 앱이 설치되어 있지 않습니다. 설치하시겠습니까?'),
            actions: <Widget>[
              TextButton(
                child: const Text('취소'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('설치하기'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  const String appStoreUrl =
                      'https://apps.apple.com/app/metamask/id1438144202';
                  const String playStoreUrl =
                      'https://play.google.com/store/apps/details?id=io.metamask';

                  String installUrl =
                      Platform.isIOS ? appStoreUrl : playStoreUrl;

                  if (await canLaunchUrl(Uri.parse(installUrl))) {
                    await launchUrl(Uri.parse(installUrl),
                        mode: LaunchMode.externalApplication);
                  } else {
                    _logger.e('$installUrl 을(를) 실행할 수 없습니다.');
                  }
                },
              ),
            ],
          );
        },
      );
    } else {
      _logger.e('알림을 표시하기 위해 네비게이터 컨텍스트에 접근할 수 없습니다.');
    }
  }

  void _showConnectionTimeoutAlert() {
    final BuildContext? context =
        NavigationService.navigatorKey.currentState?.context;
    if (context != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('연결 시간 초과'),
            content: const Text('MetaMask와의 연결이 시간 초과되었습니다. 다시 시도해주세요.'),
            actions: <Widget>[
              TextButton(
                child: const Text('확인'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } else {
      _logger.e('연결 시간 초과 알림을 표시하기 위해 네비게이터 컨텍스트에 접근할 수 없습니다.');
    }
  }

  // StreamController 닫기
  @override
  void dispose() {
    _sessionController.close();
    super.dispose();
  }

  /// MetaMask를 통해 트랜잭션을 전송하는 메서드
  Future<String?> sendTransaction(Map<String, dynamic> transactionData) async {
    if (_session == null) {
      _logger.e('트랜잭션을 전송할 활성 세션이 없습니다.');
      return null;
    }

    try {
      // 트랜잭션 데이터에서 필요한 필드 추출
      final String to = transactionData['to'];
      final String data = transactionData['data'];
      final String gas = transactionData['gas'];
      final String gasPrice = transactionData['gasPrice'];

      _logger.d('트랜잭션 전송 요청: to=$to, data=$data, gas=$gas, gasPrice=$gasPrice');

      // 트랜잭션 요청을 보냅니다
      final result = await _web3app.request(
        topic: _session!.topic,
        chainId: 'eip155:11155111', // Sepolia 테스트넷
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [
            {
              'from': walletAddress,
              'to': to,
              'data': data,
              'gas': gas,
              'gasPrice': gasPrice,
            }
          ],
        ),
      );

      _logger.d('트랜잭션 해시: $result');

      // MetaMask 앱으로 이동하도록 Deep Link 열기
      await _openMetaMaskApp();

      return result as String?;
    } catch (e, stackTrace) {
      _logger.e('트랜잭션 전송 오류: $e', e, stackTrace);
      // 사용자에게 오류 알림 표시
      final BuildContext? context =
          NavigationService.navigatorKey.currentState?.context;
      if (context != null) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('트랜잭션 전송 실패'),
              content: Text('트랜잭션 전송 중 오류가 발생했습니다: $e'),
              actions: <Widget>[
                TextButton(
                  child: const Text('확인'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
      return null;
    }
  }

  // MetaMask 앱 열기 메서드 추가
  Future<void> _openMetaMaskApp() async {
    String deepLinkUrl;

    if (Platform.isAndroid) {
      deepLinkUrl = 'metamask://';
    } else if (Platform.isIOS) {
      deepLinkUrl = 'metamask://';
    } else {
      _logger.e('지원되지 않는 플랫폼입니다.');
      return;
    }

    _logger.d('MetaMask 앱 열기: $deepLinkUrl');

    if (await canLaunchUrl(Uri.parse(deepLinkUrl))) {
      await launchUrl(Uri.parse(deepLinkUrl),
          mode: LaunchMode.externalApplication);
    } else {
      _logger.e('$deepLinkUrl 을(를) 실행할 수 없습니다.');
      // MetaMask 앱이 설치되어 있지 않을 경우 알림 표시
      _showMetaMaskNotInstalledAlert();
    }
  }
}
