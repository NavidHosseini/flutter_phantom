# flutter_phantom

- flutter_phantomt is a package based on react native phantom wallet example that allows users to connect to Phantom Wallet from their Application.
- This package is used to generate deeplink urls for Phantom Wallet to connect to your application.


## Features

This package has all these provider methods implemented for easy to use:

- [Connect](https://docs.phantom.app/integrating/deeplinks-ios-and-android/provider-methods/connect)
- [Disconnect](https://docs.phantom.app/integrating/deeplinks-ios-and-android/provider-methods/disconnect)
- [SignAndSendTransaction](https://docs.phantom.app/integrating/deeplinks-ios-and-android/provider-methods/signandsendtransaction)
- [SignAllTransactions](https://docs.phantom.app/integrating/deeplinks-ios-and-android/provider-methods/signalltransactions)
- [SignTransaction](https://docs.phantom.app/integrating/deeplinks-ios-and-android/provider-methods/signtransaction)
- [SignMessage](https://docs.phantom.app/integrating/deeplinks-ios-and-android/provider-methods/signmessage)

## Getting Started

We need to have deeplink for our application for handling returned data from phantom.

## Usage

add [`flutter_phantom`](https://pub.dev/packages/)  to  pubspec.yaml

```dart
import 'package:phantom_connect/phantom_connect.dart';
```

initialise required Parameters.

- `appUrl` A url used to fetch app metadata i.e. title, icon.
- `deepLink` The URI where Phantom should redirect the user upon connection.(Deep Link)

```dart
  final FlutterPhantom phantom = FlutterPhantom(
    appUrl: "https://phantom.app",
    deepLink: "app://mydeapp",
  );
```

## Example

- An example of how to use this package [here](https://github.com/).