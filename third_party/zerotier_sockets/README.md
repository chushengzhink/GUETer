# zerotier_sockets

[![pub package](https://img.shields.io/pub/v/zerotier_sockets.svg)](https://pub.dartlang.org/packages/zerotier_sockets)

Flutter plugin providing bindings for the [libzt](https://github.com/zerotier/libzt) library. Uses `dart:ffi`.

In order to distribute binaries it [currently](https://github.com/dart-lang/sdk/issues/50565) has to be a Flutter plugin, not a Dart package.

## Supported platforms

Currently only supports Android.

To support other platforms:
* Platform specific folder must be created with default contents
* Library file built from [libzt](https://github.com/zerotier/libzt) must be included into corresponding platform build process inside platform folder
* `loader.dart` must be fixed accordingly to include new platform

## Usage

For more detailed usage see `example` folder. Also refer to [ZeroTier Sockets tutorial](https://docs.zerotier.com/sockets/tutorial.html).

Only client TCP sockets are implemented yet.

```dart
import 'package:zerotier_sockets/zerotier_sockets.dart';
import 'package:path_provider/path_provider.dart';

Future<void> startNodeAndConnectToNetwork(String networkId) async {
  // obtain node instance
  var node = ZeroTierNode.instance;

  // set persistent storage path to have identity and network configuration cached
  // you can also use initSetIdentity to set identity from memory but network configs won't be cached
  var appDocPath = (await getApplicationDocumentsDirectory()).path + '/zerotier_node';
  node.initSetPath(appDocPath);

  // try to start
  var result = node.start();
  if (!result.success) {
    throw Exception('Failed to start node: $result');
  }

  await node.waitForOnline();

  // parse network id from hex string
  var nwId = BigInt.parse(networkId, radix: 16);

  // join network
  result = node.join(nwId);
  if (!result.success) {
    throw Exception('Failed to join network: $result');
  }

  await node.waitForNetworkReady(nwId);
  await node.waitForAddressAssignment(nwId);

  // get network info
  var networkInfo = node.getNetworkInfo(nwId);
  print(networkInfo.name);
  print(networkInfo.address);
  print(networkInfo.id);

  ZeroTierSocket socket;
  try {
    // connect socket
    socket = await ZeroTierSocket.connect('10.144.242.244', 22);
  } catch (e) {
    print('Failed to connect socket: $e');
    socket.close();
    return;
  }

  // send data
  socket.sink.add([1, 2, 3, 4, 5]);

  // listen for data
  socket.stream.listen((data) => print('received ${data.length} byte(s)'));

  // detect socket close
  socket.done.then((_) => print('socket closed'));

  // don't forget to close sockets
  socket.close();
}
```

## Events

`libzt` provides a way to pass a callback method that is called from background thread when an event happens.

The problem is that Dart and Flutter do not support invoking into isolate thread.

The ways to work that around:

* Fork `libzt` and use `Dart_Port` as explained [here](https://gist.github.com/espresso3389/be5674ab4e3154f0b7c43715dcef3d8d)

* Wait for Dart team to [implement calls from background threads](https://github.com/dart-lang/sdk/issues/37022)

* Platform channels can be used as well but must be implemented for each platform separately which is not ideal. Also Java API passes a limited set of events and data

In first two scenarios `libzt` must be built with `ZTS_C_API_ONLY` def, because Java callbacks will not be used.
