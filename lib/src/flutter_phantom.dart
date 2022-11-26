import 'dart:convert';

import 'package:pinenacl/x25519.dart';
import 'package:solana_web3/solana_web3.dart' as web3;

/// flutter_phantom that allows users to connect to Phantom Wallet
/// This package is written from the "deep-link-demo-app(react native)" example
/// in the [deep-link-demo-app](https://github.com/phantom-labs/deep-link-demo-app) repository
class FlutterPhantom {
  static const String scheme = "https";
  static const String host = "phantom.app";

  String? _session;

  late PrivateKey _dAppSecretKey;
  late PublicKey dAppPublicKey;

  /// [appUrl] is used to fetch app metadata (i.e. title, icon) using the
  /// same properties found in Displaying Your App.
  String appUrl;

  /// [phantomWalletPublicKey]  once session is established with Phantom Wallet (i.e. user has approved the connection) we get user's Publickey.
  late web3.PublicKey phantomWalletPublicKey;

  /// [deepLink] uri is used to open the app from Phantom Wallet i.e our app's deeplink.
  String deepLink;

  /// [_sharedSecret] is used to encrypt and decrypt the session token and other data.
  Box? _sharedSecret;

  FlutterPhantom({required this.appUrl, required this.deepLink}) {
    _dAppSecretKey = PrivateKey.generate();
    dAppPublicKey = _dAppSecretKey.publicKey;
  }

  Uri generateConnectUri({required String cluster, required String redirect}) {
    return Uri(
      scheme: scheme,
      host: host,
      path: '/ul/v1/connect',
      queryParameters: {
        'dapp_encryption_public_key':
            web3.base58Encode(dAppPublicKey.toUint8List()),
        'cluster': cluster,
        'app_url': appUrl,
        'redirect_link': "$deepLink?handleQuery=$redirect",
      },
    );
  }

  Map onConnectToWallet(
      List<MapEntry<String, List<String>>> queryParamsFromPhantom) {
    String phantomPKey = queryParamsFromPhantom
        .singleWhere((element) =>
            element.key.toString() == "phantom_encryption_public_key")
        .value[0]
        .toString();

    String nonce = queryParamsFromPhantom
        .singleWhere((element) => element.key.toString() == "nonce")
        .value[0];

    String data = queryParamsFromPhantom
        .singleWhere((element) => element.key.toString() == "data")
        .value[0];

    Box sharedSecretDapp = Box(
        myPrivateKey: _dAppSecretKey,
        theirPublicKey:
            PublicKey(Uint8List.fromList(web3.base58Decode(phantomPKey))));

    _sharedSecret = sharedSecretDapp;
    Map onConnectData = decryptPayload(data, nonce, sharedSecretDapp);

    phantomWalletPublicKey =
        web3.PublicKey.fromString(onConnectData['public_key'].toString());

    _session = onConnectData['session'].toString();
    return onConnectData;
  }

  Uri generateSignAndSendTransactionUri(
      {required web3.Buffer transaction, required String redirect}) {
    var payload = {
      "session": _session,
      "transaction": web3.base58Encode(transaction.asUint8List()),
    };
    final getData = encryptPayload(payload);
    final nonce = getData[0];
    final ByteList encryptedPayload = getData[1];

    return Uri(
      scheme: scheme,
      host: host,
      path: '/ul/v1/signAndSendTransaction',
      queryParameters: {
        "dapp_encryption_public_key":
            web3.base58Encode(dAppPublicKey.asTypedList),
        "nonce": web3.base58Encode(nonce),
        'redirect_link': "$deepLink?handleQuery=$redirect",
        'payload': web3.base58Encode(encryptedPayload.asTypedList)
      },
    );
  }

  Map<dynamic, dynamic> onCreateSignAndSendTransactionReceive(
      List<MapEntry<String, List<String>>> queryParams) {
    String nonce = queryParams
        .singleWhere((element) => element.key.toString() == "nonce")
        .value[0];

    String data = queryParams
        .singleWhere((element) => element.key.toString() == "data")
        .value[0];

    Map onCreateAndSendTransactionResult =
        decryptPayload(data, nonce, _sharedSecret!);

    return onCreateAndSendTransactionResult;
  }

  web3.Transaction onSignTransactionReceive(
      List<MapEntry<String, List<String>>> queryParams) {
    String nonce = queryParams
        .singleWhere((element) => element.key.toString() == "nonce")
        .value[0];

    String data = queryParams
        .singleWhere((element) => element.key.toString() == "data")
        .value[0];

    Map<dynamic, dynamic> onSignTransactionReceiveResult =
        decryptPayload(data, nonce, _sharedSecret!);

    Map<String, dynamic> transactionEncode =
        onSignTransactionReceiveResult.cast<String, dynamic>();
    var transaction = web3.base58Decode(transactionEncode['transaction']);

    web3.Transaction decodedTransaction =
        web3.Transaction.fromList(transaction);
    return decodedTransaction;
  }

  List<web3.Transaction> onSignAllTransactionReceive(
      List<MapEntry<String, List<String>>> queryParams) {
    String nonce = queryParams
        .singleWhere((element) => element.key.toString() == "nonce")
        .value[0];

    String data = queryParams
        .singleWhere((element) => element.key.toString() == "data")
        .value[0];

    Map<dynamic, dynamic> onSignTransactionReceiveResult =
        decryptPayload(data, nonce, _sharedSecret!);

    Map<String, dynamic> transactionsEncode =
        onSignTransactionReceiveResult.cast<String, dynamic>();
    List<String> listTransactionsEncode =
        List<String>.from(transactionsEncode['transactions'] as List);
    List<web3.Transaction> listTransactionsDecode = listTransactionsEncode
        .map((e) => web3.Transaction.fromList(web3.base58Decode(e)))
        .toList();

    return listTransactionsDecode;
  }

  String onDisconnectReceive() {
    return "disConnect";
  }

  Uri generateDisconnectUri({required String redirect}) {
    var payLoad = {
      "session": _session,
    };
    final getData = encryptPayload(payLoad);
    final nonce = getData[0];
    final ByteList encryptedPayload = getData[1];

    Uri launchUri = Uri(
      scheme: scheme,
      host: host,
      path: '/ul/v1/disconnect',
      queryParameters: {
        "dapp_encryption_public_key":
            web3.base58Encode(dAppPublicKey.asTypedList),
        "nonce": web3.base58Encode(nonce),
        'redirect_link': "$deepLink?handleQuery=$redirect",
        "payload": web3.base58Encode(encryptedPayload.asTypedList),
      },
    );
    _sharedSecret = null;
    return launchUri;
  }

  Uri generateSignTransactionUri(
      {required String transaction, required String redirect}) {
    var payload = {
      "session": _session,
      "transaction": transaction,
    };
    final getData = encryptPayload(payload);
    final nonce = getData[0];
    final ByteList encryptedPayload = getData[1];

    return Uri(
      scheme: scheme,
      host: host,
      path: '/ul/v1/signTransaction',
      queryParameters: {
        "dapp_encryption_public_key":
            web3.base58Encode(dAppPublicKey.asTypedList),
        "nonce": web3.base58Encode(nonce),
        'redirect_link': "$deepLink?handleQuery=$redirect",
        'payload': web3.base58Encode(encryptedPayload.asTypedList)
      },
    );
  }

  Uri generateUriSignAllTransactions(
      {required List<String> transactions, required String redirect}) {
    var payload = {"session": _session, "transactions": transactions};
    final getData = encryptPayload(payload);
    final nonce = getData[0];
    final ByteList encryptedPayload = getData[1];

    return Uri(
      scheme: 'https',
      host: 'phantom.app',
      path: '/ul/v1/signAllTransactions',
      queryParameters: {
        "dapp_encryption_public_key":
            web3.base58Encode(dAppPublicKey.asTypedList),
        "nonce": web3.base58Encode(nonce),
        'redirect_link': "$deepLink?handleQuery=$redirect",
        'payload': web3.base58Encode(encryptedPayload.asTypedList)
      },
    );
  }

  Uri generateSignMessageUri(
      {required String redirect, required String message}) {
    var payload = {
      "session": _session,
      "message": web3.base58Encode(message.codeUnits.toUint8List()),
    };

    final getData = encryptPayload(payload);
    final nonce = getData[0];
    final ByteList encryptedPayload = getData[1];

    return Uri(
      scheme: scheme,
      host: host,
      path: 'ul/v1/signMessage',
      queryParameters: {
        "dapp_encryption_public_key":
            web3.base58Encode(Uint8List.fromList(dAppPublicKey)),
        "nonce": web3.base58Encode(nonce),
        'redirect_link': "$deepLink?handleQuery=$redirect",
        'payload': web3.base58Encode(encryptedPayload.asTypedList)
      },
    );
  }

  Map<dynamic, dynamic> onSignMessageReceive(
      List<MapEntry<String, List<String>>> queryParams) {
    String nonce = queryParams
        .singleWhere((element) => element.key.toString() == "nonce")
        .value[0];

    String data = queryParams
        .singleWhere((element) => element.key.toString() == "data")
        .value[0];

    Map onCreateAndSendTransactionResult =
        decryptPayload(data, nonce, _sharedSecret!);

    return onCreateAndSendTransactionResult;
  }

  /// Decrypts the [data] payload returned by Phantom Wallet
  Map<dynamic, dynamic> decryptPayload(
      String data, String nonce, Box sharedSecret) {
    if (sharedSecret.isEmpty) throw ("missing shared secret");

    Uint8List decryptedData = sharedSecret.decrypt(
      ByteList(web3.base58Decode(data)),
      nonce: Uint8List.fromList(web3.base58Decode(nonce)),
    );
    if (decryptedData.isEmpty) throw ("Unable to decrypt data");
    return jsonDecode(String.fromCharCodes(decryptedData));
  }

  /// Encrypts the data payload to be sent to Phantom Wallet.
  ///
  /// - Returns the encrypted `payload` and `nonce`.
  encryptPayload(payload) {
    final nonce = PineNaClUtils.randombytes(24);
    List<int> list = utf8.encode(jsonEncode(payload));
    Uint8List bytes = Uint8List.fromList(list);
    var encryptedPayload =
        _sharedSecret!.encrypt(bytes, nonce: nonce).cipherText;
    return [nonce, encryptedPayload];
  }
}
