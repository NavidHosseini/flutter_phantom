import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_phantom/flutter_phantom.dart';
import 'package:uni_links/uni_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:solana_web3/solana_web3.dart' as web3;
import 'package:solana_web3/programs/system.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Uri? _latestUri;
  late StreamSubscription _sub;
  String logger = "";
  bool isLoading = false;
  ScrollController scrollController = ScrollController();

  final FlutterPhantom phantom = FlutterPhantom(
    appUrl: "https://phantom.app",
    deepLink: "app://mydeapp",
  );

  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _handleIncomingLinks() async {
    _sub = uriLinkStream.listen((Uri? link) {
      _latestUri = link;
      final queryParams = _latestUri?.queryParametersAll.entries.toList();

      if (queryParams!.isNotEmpty) {
        switch (queryParams[0].value[0].toString()) {
          case "onConnect":
            Map dataConnect = phantom.onConnectToWallet(queryParams);
            inspect(dataConnect);

            textLogger(dataConnect.toString());
            break;
          case "onSignAndSendTransaction":
            Map dataSignAndSendTransaction =
                phantom.onCreateSignAndSendTransactionReceive(queryParams);
            inspect(dataSignAndSendTransaction);
            textLogger(dataSignAndSendTransaction.toString());
            break;
          case "onDisconnect":
            String dataDisconnect = phantom.onDisconnectReceive();
            textLogger(dataDisconnect.toString());
            break;
          case "onSignTransaction":
            web3.Transaction dataTransactionWithSign =
                phantom.onSignTransactionReceive(queryParams);
            inspect(dataTransactionWithSign);
            textLogger("transaction sign");

            break;
          case "onSignAllTransaction":
            List<web3.Transaction> dataSignAllTransaction =
                phantom.onSignAllTransactionReceive(queryParams);
            inspect(dataSignAllTransaction);
            textLogger("All transactions sign");
            break;
          case "onSignMessage":
            Map dataOnSignMessage = phantom.onSignMessageReceive(queryParams);
            inspect(dataOnSignMessage);
            textLogger(dataOnSignMessage.toString());

            break;
          default:
        }
      }
    }, onError: (err) {
      // Handle exception by warning the user their action did not succeed
    });
  }

  void textLogger(String text) {
    if (logger.isEmpty) {
      setState(() {
        logger = '$text'
            '\n'
            '--------------------------------------------------------'
            '\n';
      });
    } else {
      setState(() {
        logger = '$logger'
            '$text'
            '\n'
            '--------------------------------------------------------'
            '\n';
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          curve: Curves.easeOut,
          duration: const Duration(milliseconds: 500),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cluster = web3.Cluster.devnet;
    final connection = web3.Connection(cluster);

    void connectToWallet() {
      try {
        setState(() {
          isLoading = true;
        });
        Uri uri = phantom.generateConnectUri(
            cluster: "devnet", redirect: "onConnect");
        setState(() {
          isLoading = false;
        });
        launchUrl(
          uri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        textLogger("error, $e");
      }
    }

    Future<web3.Transaction> createTransactionTransfer() async {
      final transaction = web3.Transaction(
          feePayer: phantom.phantomWalletPublicKey,
          recentBlockhash: (await connection.getLatestBlockhash()).blockhash);
      transaction.add(
        SystemProgram.transfer(
          fromPublicKey: phantom.phantomWalletPublicKey,
          toPublicKey: phantom.phantomWalletPublicKey,
          lamports: web3.solToLamports(1),
        ),
      );

      return transaction;
    }

    void signAndSendTransaction() async {
      try {
        setState(() {
          isLoading = true;
        });
        web3.Transaction transaction = await createTransactionTransfer();

        web3.Buffer transactionSerialize = transaction
            .serialize(const web3.SerializeConfig(requireAllSignatures: false));

        final url = phantom.generateSignAndSendTransactionUri(
            transaction: transactionSerialize,
            redirect: "onSignAndSendTransaction");
        setState(() {
          isLoading = false;
        });
        launchUrl(
          url,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        textLogger("error,  make sure your connect to wallet \n \n <<$e>> ");
      }
    }

    void signAndSendTransactionToProgram() async {
      try {
        setState(() {
          isLoading = true;
        });
        final web3.PublicKey programId = web3.PublicKey.fromString(
            "DWX4sCH7wFiNPXDxyJBMCT5m84xXFznbhhq1rqi1Fxuk");

        var instruction = web3.TransactionInstruction(
          keys: [
            web3.AccountMeta(
              phantom.phantomWalletPublicKey,
              isSigner: true,
              isWritable: false,
            )
          ],
          programId: programId,
        );

        final transaction = web3.Transaction(
            feePayer: phantom.phantomWalletPublicKey,
            recentBlockhash: (await connection.getLatestBlockhash()).blockhash);
        transaction.add(instruction);

        web3.Buffer transactionSerialize = transaction
            .serialize(const web3.SerializeConfig(requireAllSignatures: false));
        final url = phantom.generateSignAndSendTransactionUri(
            transaction: transactionSerialize,
            redirect: "onSignAndSendTransaction");
        setState(() {
          isLoading = false;
        });
        launchUrl(
          url,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        textLogger("error,  make sure your connect to wallet \n \n <<$e>> ");
      }
    }

    void disconnectToPhantom() {
      try {
        setState(() {
          isLoading = true;
        });
        var url = phantom.generateDisconnectUri(redirect: "onDisconnect");
        setState(() {
          isLoading = false;
        });
        launchUrl(
          url,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        textLogger("error,  you are not connect to wallet");
      }
    }

    void signTransaction() async {
      try {
        setState(() {
          isLoading = true;
        });
        final web3.PublicKey programId = web3.PublicKey.fromString(
            "DWX4sCH7wFiNPXDxyJBMCT5m84xXFznbhhq1rqi1Fxuk");
        var instruction = web3.TransactionInstruction(
          keys: [
            web3.AccountMeta(
              phantom.phantomWalletPublicKey,
              isSigner: true,
              isWritable: false,
            ),
          ],
          programId: programId,
        );

        final transaction = web3.Transaction(
            feePayer: phantom.phantomWalletPublicKey,
            recentBlockhash: (await connection.getLatestBlockhash()).blockhash);
        transaction.add(instruction);

        String transactionString = web3.base58Encode(transaction
            .serialize(const web3.SerializeConfig(requireAllSignatures: false))
            .asUint8List());

        final url = phantom.generateSignTransactionUri(
            transaction: transactionString, redirect: "onSignTransaction");
        setState(() {
          isLoading = false;
        });
        launchUrl(
          url,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        textLogger("error,  make sure your connect to wallet \n \n <<$e>> ");
      }
    }

    void signAllTransaction() async {
      try {
        setState(() {
          isLoading = true;
        });
        web3.Transaction transaction1 = await createTransactionTransfer();
        web3.Transaction transaction2 = await createTransactionTransfer();
        List<web3.Transaction> transactions = [transaction1, transaction2];
        List<String> serializeTransactions = transactions
            .map(
              (e) => web3.base58Encode(e
                  .serialize(
                      const web3.SerializeConfig(requireAllSignatures: false))
                  .asUint8List()),
            )
            .toList();
        final url = phantom.generateUriSignAllTransactions(
            transactions: serializeTransactions,
            redirect: "onSignAllTransaction");
        setState(() {
          isLoading = false;
        });
        launchUrl(
          url,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        textLogger("error,  make sure your connect to wallet \n \n <<$e>> ");
      }
    }

    void signMessage() {
      try {
        setState(() {
          isLoading = true;
        });
        final url = phantom.generateSignMessageUri(
            redirect: "onSignMessage", message: "hello from flutter");
        setState(() {
          isLoading = false;
        });
        launchUrl(
          url,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        textLogger("error,  make sure your connect to wallet \n \n <<$e>> ");
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("flutter phantom demo"),
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * .3,
            color: Colors.black,
            child: SingleChildScrollView(
              controller: scrollController,
              child: Text(
                logger,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          isLoading
              ? const Expanded(
                  child: Center(child: CircularProgressIndicator()))
              : Column(
                  children: [
                    Button(
                      onPress: connectToWallet,
                      text: "connect",
                      isLoading: isLoading,
                    ),
                    Button(
                      onPress: disconnectToPhantom,
                      text: "disconnect",
                      isLoading: isLoading,
                    ),
                    Button(
                      onPress: signTransaction,
                      text: "signTransaction",
                      isLoading: isLoading,
                    ),
                    Button(
                      onPress: signAllTransaction,
                      text: "sign All Transaction",
                      isLoading: isLoading,
                    ),
                    Button(
                      onPress: signAndSendTransaction,
                      text: "signAndSendTransaction (Transfer)",
                      isLoading: isLoading,
                    ),
                    Button(
                      onPress: signAndSendTransactionToProgram,
                      text: "signAndSendTransaction (program)",
                      isLoading: isLoading,
                    ),
                    Button(
                      onPress: signMessage,
                      text: "SignMessage",
                      isLoading: isLoading,
                    ),
                  ],
                )
        ],
      ),
    );
  }
}

class Button extends StatelessWidget {
  final void Function() onPress;
  final String text;
  final bool isLoading;
  const Button(
      {Key? key,
      required this.onPress,
      required this.text,
      required this.isLoading})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      width: MediaQuery.of(context).size.width,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPress,
        child: Text(text),
      ),
    );
  }
}
