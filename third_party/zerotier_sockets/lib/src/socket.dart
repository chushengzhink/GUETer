import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'native_utils.dart';
import 'result.dart';
import 'zts.dart';

/// Socket connection established via libzt
class ZeroTierSocket {
  static Future<ZeroTierSocket> connect(
    String address,
    int port, {
    Duration timeout = const Duration(seconds: 5),
    int readSize = 4096,
    void Function(String)? onDebugLog,
  }) async {
    var ts = DateTime.now();

    int fd;
    if ((fd = zts.socket(ZTS_AF_INET, ZTS_SOCK_STREAM, ZTS_IPPROTO_TCP)) < 0) {
      throw SocketException(ZeroTierResult(fd, zts.zts_errno).toString());
    }

    int res;
    if ((res = zts.set_blocking(fd, 0)) < 0) {
      var errno = zts.zts_errno;
      zts.shutdown_rdwr(fd);
      zts.close(fd);
      throw SocketException(ZeroTierResult(res, errno).toString());
    }

    /*var hostPtr = NativeString(address);
    try {
      if ((res = zts.connect(fd, hostPtr.pointer, port, 0)) < 0) {
        var errno = zts.zts_errno;
        if (res == -1 && errno == zts_errno_t.ZTS_EINPROGRESS) {
          // ok
        } else {
          zts.shutdown_rdwr(fd);
          zts.close(fd);
          throw SocketException(ZeroTierResult(res, errno).toString());
        }
      }
    } finally {
      hostPtr.free();
    }*/

    // zts_connect doesn't even try to connect in non-blocking mode, so here is a port of it which does
    var ipstr = NativeString(address);
    var ss = malloc<zts_sockaddr_storage>(1);
    var addrlen = NativeUnsignedInt(sizeOf<zts_sockaddr_storage>());
    res = zts.util_ipstr_to_saddr(ipstr.pointer, port, ss.cast(), addrlen.pointer.cast());

    try {
      if ((res = zts.bsd_connect(fd, ss.cast(), addrlen.value)) < 0) {
        var errno = zts.zts_errno;
        if (res == -1 && errno == zts_errno_t.ZTS_EINPROGRESS) {
          // ok
        } else {
          zts.shutdown_rdwr(fd);
          zts.close(fd);
          throw SocketException(ZeroTierResult(res, errno).toString());
        }
      }
    } finally {
      ipstr.free();
      malloc.free(ss);
      addrlen.free();
    }

    var fds = malloc<zts_pollfd>(1);
    var fdsVal = fds.ref;
    fdsVal.fd = fd;
    fdsVal.events = ZTS_POLLOUT | ZTS_POLLIN | ZTS_POLLERR;
    fdsVal.revents = 0;
    fds.ref = fdsVal;

    try {
      while (true) {
        var res = zts.bsd_poll(fds, 1, 0);
        var errno = zts.zts_errno;

        if (res == 1) {
          var revents = fds.ref.revents;
          if ((revents & ZTS_POLLERR) != 0) {
            errno = zts.get_last_socket_error(fd);
            zts.shutdown_rdwr(fd);
            zts.close(fd);
            throw SocketException(ZeroTierResult(res, errno).toString());
          } else if ((revents & ZTS_POLLOUT) != 0) {
            break;
          }
          break;
        } else if (res < 0) {
          zts.shutdown_rdwr(fd);
          zts.close(fd);
          throw SocketException(ZeroTierResult(res, errno).toString());
        }

        await Future.delayed(const Duration(milliseconds: 10));

        if (DateTime.now().difference(ts) > timeout) {
          zts.shutdown_rdwr(fd);
          zts.close(fd);
          throw const SocketException('Connection timed out (ZeroTier)');
        }
      }
    } finally {
      malloc.free(fds);
    }

    onDebugLog?.call('ZeroTierSocket open fd $fd');

    return ZeroTierSocket._(fd, readSize, onDebugLog);
  }

  ZeroTierSocket._(this._fd, this._readSize, this._onDebugLog) {
    _in = StreamController<List<int>>();
    _inSub = _in.stream.listen(_onWrite);
    _out = StreamController<Uint8List>();
    _doneCompleter = Completer();
    _startReader();
  }

  final int _fd;
  final int _readSize;
  final void Function(String)? _onDebugLog;

  bool _isOpen = true;

  late final StreamController<Uint8List> _out;
  late final StreamController<List<int>> _in;
  late final StreamSubscription<List<int>> _inSub;
  late final Completer _doneCompleter;

  Stream<Uint8List> get stream => _out.stream;
  StreamSink<List<int>> get sink => _in.sink;

  Future<void> get done => _doneCompleter.future;

  Future<void> close() async {
    if (_isOpen) {
      _isOpen = false;
      _onDebugLog?.call('$runtimeType close $_fd');
      zts.shutdown_rdwr(_fd);
      zts.close(_fd);
      _in.close();
      _inSub.cancel();
      _out.close();
      if (!_doneCompleter.isCompleted) {
        _doneCompleter.complete();
      }
    }
    return _doneCompleter.future;
  }

  void destroy() {
    close();
  }

  Future _startReader() async {
    var dataPtr = NativeByteArray.empty(_readSize);

    try {
      while (_isOpen) {
        final res = zts.read(_fd, dataPtr.voidPointer, _readSize);
        final errno = zts.zts_errno;
        if (res > 0) {
          _onDebugLog?.call('$runtimeType read from fd $_fd: $res bytes');
          final data = dataPtr.data.sublist(0, res);
          _out.add(data);
        } else if (res == 0) {
        } else if (res == -1 && errno == zts_errno_t.ZTS_EWOULDBLOCK) {
          // ignore
        } else {
          close();
        }

        await Future.delayed(const Duration(milliseconds: 10));
      }
    } finally {
      dataPtr.free();
    }
  }

  void _onWrite(List<int> data) {
    var dataPtr = NativeByteArray(Uint8List.fromList(data));
    try {
      final res = zts.send(_fd, dataPtr.voidPointer, data.length, 0);
      _onDebugLog?.call('$runtimeType write to fd $_fd: $res bytes');
      if (res < 0) {
        close();
      }
    } finally {
      dataPtr.free();
    }
  }
}
