import 'bindings.dart';
import 'error.dart';
import 'socket_error.dart';
import 'zts.dart';

/// libzt operation result
class ZeroTierResult {
  ZeroTierResult(int res, [int errno = 0]) {
    result = res;
    success = res >= zts_error_t.ZTS_ERR_OK || res < zts_error_t.ZTS_ERR_GENERAL;
    if (!success) {
      errorType = getErrorType(res);
      errorMessage = getErrorMessage(res);
    } else {
      errorType = ZtsError.none;
      errorMessage = null;
    }
    if (errno != 0) {
      socketErrorType = getSocketError(errno);
      socketErrorMessage = getSocketErrorMessage(errno);
    } else if (result == -1) {
      var socketError = zts.zts_errno;
      socketErrorType = getSocketError(socketError);
      socketErrorMessage = getSocketErrorMessage(socketError);
    } else {
      socketErrorType = null;
      socketErrorMessage = null;
    }
  }

  static ZtsError getErrorType(int res) {
    switch (res) {
      case zts_error_t.ZTS_ERR_SOCKET:
        return ZtsError.socketError;
      case zts_error_t.ZTS_ERR_SERVICE:
        return ZtsError.nodeServiceError;
      case zts_error_t.ZTS_ERR_ARG:
        return ZtsError.invalidArgument;
      case zts_error_t.ZTS_ERR_NO_RESULT:
        return ZtsError.noResult;
      case zts_error_t.ZTS_ERR_GENERAL:
        return ZtsError.generalError;
      default:
        return ZtsError.none;
    }
  }

  static String? getErrorMessage(int res) {
    switch (res) {
      case -1:
        return 'Socket error (ZTS_ERR_SOCKET)';
      case -2:
        return 'The node service experienced a problem (ZTS_ERR_SERVICE)';
      case -3:
        return 'Invalid argument (ZTS_ERR_ARG)';
      case -4:
        return 'No result (not necessarily an error) (ZTS_ERR_NO_RESULT)';
      case -5:
        return 'Consider filing a bug report (ZTS_ERR_GENERAL)';
      default:
        return res.toString();
    }
  }

  ZtsSocketError? getSocketError(int socketError) {
    switch (socketError) {
      case zts_errno_t.ZTS_EPERM:
        return ZtsSocketError.eperm;
      case zts_errno_t.ZTS_ENOENT:
        return ZtsSocketError.enoent;
      case zts_errno_t.ZTS_ESRCH:
        return ZtsSocketError.esrch;
      case zts_errno_t.ZTS_EINTR:
        return ZtsSocketError.eintr;
      case zts_errno_t.ZTS_EIO:
        return ZtsSocketError.eio;
      case zts_errno_t.ZTS_ENXIO:
        return ZtsSocketError.enxio;
      case zts_errno_t.ZTS_EBADF:
        return ZtsSocketError.ebadf;
      case zts_errno_t.ZTS_EAGAIN:
        //case zts_errno_t.ZTS_EWOULDBLOCK:
        return ZtsSocketError.eagain;
      case zts_errno_t.ZTS_ENOMEM:
        return ZtsSocketError.enomem;
      case zts_errno_t.ZTS_EACCES:
        return ZtsSocketError.eacces;
      case zts_errno_t.ZTS_EFAULT:
        return ZtsSocketError.efault;
      case zts_errno_t.ZTS_EBUSY:
        return ZtsSocketError.ebusy;
      case zts_errno_t.ZTS_EEXIST:
        return ZtsSocketError.eexist;
      case zts_errno_t.ZTS_ENODEV:
        return ZtsSocketError.enodev;
      case zts_errno_t.ZTS_EINVAL:
        return ZtsSocketError.einval;
      case zts_errno_t.ZTS_ENFILE:
        return ZtsSocketError.enfile;
      case zts_errno_t.ZTS_EMFILE:
        return ZtsSocketError.emfile;
      case zts_errno_t.ZTS_ENOSYS:
        return ZtsSocketError.enosys;
      case zts_errno_t.ZTS_ENOTSOCK:
        return ZtsSocketError.enotsock;
      case zts_errno_t.ZTS_EDESTADDRREQ:
        return ZtsSocketError.edestaddrreq;
      case zts_errno_t.ZTS_EMSGSIZE:
        return ZtsSocketError.emsgsize;
      case zts_errno_t.ZTS_EPROTOTYPE:
        return ZtsSocketError.eprototype;
      case zts_errno_t.ZTS_ENOPROTOOPT:
        return ZtsSocketError.enoprotoopt;
      case zts_errno_t.ZTS_EPROTONOSUPPORT:
        return ZtsSocketError.eprotonosupport;
      case zts_errno_t.ZTS_ESOCKTNOSUPPORT:
        return ZtsSocketError.esocktnosupport;
      case zts_errno_t.ZTS_EOPNOTSUPP:
        return ZtsSocketError.eopnotsupp;
      case zts_errno_t.ZTS_EPFNOSUPPORT:
        return ZtsSocketError.epfnosupport;
      case zts_errno_t.ZTS_EAFNOSUPPORT:
        return ZtsSocketError.eafnosupport;
      case zts_errno_t.ZTS_EADDRINUSE:
        return ZtsSocketError.eaddrinuse;
      case zts_errno_t.ZTS_EADDRNOTAVAIL:
        return ZtsSocketError.eaddrnotavail;
      case zts_errno_t.ZTS_ENETDOWN:
        return ZtsSocketError.enetdown;
      case zts_errno_t.ZTS_ENETUNREACH:
        return ZtsSocketError.enetunreach;
      case zts_errno_t.ZTS_ECONNABORTED:
        return ZtsSocketError.econnaborted;
      case zts_errno_t.ZTS_ECONNRESET:
        return ZtsSocketError.econnreset;
      case zts_errno_t.ZTS_ENOBUFS:
        return ZtsSocketError.enobufs;
      case zts_errno_t.ZTS_EISCONN:
        return ZtsSocketError.eisconn;
      case zts_errno_t.ZTS_ENOTCONN:
        return ZtsSocketError.enotconn;
      case zts_errno_t.ZTS_ETIMEDOUT:
        return ZtsSocketError.etimedout;
      case zts_errno_t.ZTS_ECONNREFUSED:
        return ZtsSocketError.econnrefused;
      case zts_errno_t.ZTS_EHOSTUNREACH:
        return ZtsSocketError.ehostunreach;
      case zts_errno_t.ZTS_EALREADY:
        return ZtsSocketError.ealready;
      case zts_errno_t.ZTS_EINPROGRESS:
        return ZtsSocketError.einprogress;
      default:
        return null;
    }
  }

  String? getSocketErrorMessage(int socketError) {
    switch (socketError) {
      case zts_errno_t.ZTS_EPERM:
        return 'Operation not permitted (ZTS_EPERM)';
      case zts_errno_t.ZTS_ENOENT:
        return 'No such file or directory (ZTS_ENOENT)';
      case zts_errno_t.ZTS_ESRCH:
        return 'No such process (ZTS_ESRCH)';
      case zts_errno_t.ZTS_EINTR:
        return 'Interrupted system call (ZTS_EINTR)';
      case zts_errno_t.ZTS_EIO:
        return 'I/O error (ZTS_EIO)';
      case zts_errno_t.ZTS_ENXIO:
        return 'No such device or address (ZTS_ENXIO)';
      case zts_errno_t.ZTS_EBADF:
        return 'Bad file number (ZTS_EBADF)';
      case zts_errno_t.ZTS_EWOULDBLOCK:
        return 'Try again / Operation would block (ZTS_EWOULDBLOCK)';
      case zts_errno_t.ZTS_ENOMEM:
        return 'Out of memory (ZTS_ENOMEM)';
      case zts_errno_t.ZTS_EACCES:
        return 'Permission denied (ZTS_EACCES)';
      case zts_errno_t.ZTS_EFAULT:
        return 'Bad address (ZTS_EFAULT)';
      case zts_errno_t.ZTS_EBUSY:
        return 'Device or resource busy (ZTS_EBUSY)';
      case zts_errno_t.ZTS_EEXIST:
        return 'File exists (ZTS_EEXIST)';
      case zts_errno_t.ZTS_ENODEV:
        return 'No such device (ZTS_ENODEV)';
      case zts_errno_t.ZTS_EINVAL:
        return 'Invalid argument (ZTS_EINVAL)';
      case zts_errno_t.ZTS_ENFILE:
        return 'File table overflow (ZTS_ENFILE)';
      case zts_errno_t.ZTS_EMFILE:
        return 'Too many open files (ZTS_EMFILE)';
      case zts_errno_t.ZTS_ENOSYS:
        return 'Function not implemented (ZTS_ENOSYS)';
      case zts_errno_t.ZTS_ENOTSOCK:
        return 'Socket operation on non-socket (ZTS_ENOTSOCK)';
      case zts_errno_t.ZTS_EDESTADDRREQ:
        return 'Destination address required (ZTS_EDESTADDRREQ)';
      case zts_errno_t.ZTS_EMSGSIZE:
        return 'Message too long (ZTS_EMSGSIZE)';
      case zts_errno_t.ZTS_EPROTOTYPE:
        return 'Protocol wrong type for socket (ZTS_EPROTOTYPE)';
      case zts_errno_t.ZTS_ENOPROTOOPT:
        return 'Protocol not available (ZTS_ENOPROTOOPT)';
      case zts_errno_t.ZTS_EPROTONOSUPPORT:
        return 'Protocol not supported (ZTS_EPROTONOSUPPORT)';
      case zts_errno_t.ZTS_ESOCKTNOSUPPORT:
        return 'Socket type not supported (ZTS_ESOCKTNOSUPPORT)';
      case zts_errno_t.ZTS_EOPNOTSUPP:
        return 'Operation not supported on transport endpoint (ZTS_EOPNOTSUPP)';
      case zts_errno_t.ZTS_EPFNOSUPPORT:
        return 'Protocol family not supported (ZTS_EPFNOSUPPORT)';
      case zts_errno_t.ZTS_EAFNOSUPPORT:
        return 'Address family not supported by protocol (ZTS_EAFNOSUPPORT)';
      case zts_errno_t.ZTS_EADDRINUSE:
        return 'Address already in use (ZTS_EADDRINUSE)';
      case zts_errno_t.ZTS_EADDRNOTAVAIL:
        return 'Cannot assign requested address (ZTS_EADDRNOTAVAIL)';
      case zts_errno_t.ZTS_ENETDOWN:
        return 'Network is down (ZTS_ENETDOWN)';
      case zts_errno_t.ZTS_ENETUNREACH:
        return 'Network is unreachable (ZTS_ENETUNREACH)';
      case zts_errno_t.ZTS_ECONNABORTED:
        return 'Software caused connection abort (ZTS_ECONNABORTED)';
      case zts_errno_t.ZTS_ECONNRESET:
        return 'Connection reset by peer (ZTS_ECONNRESET)';
      case zts_errno_t.ZTS_ENOBUFS:
        return 'No buffer space available (ZTS_ENOBUFS)';
      case zts_errno_t.ZTS_EISCONN:
        return 'Transport endpoint is already connected (ZTS_EISCONN)';
      case zts_errno_t.ZTS_ENOTCONN:
        return 'Transport endpoint is not connected (ZTS_ENOTCONN)';
      case zts_errno_t.ZTS_ETIMEDOUT:
        return 'Connection timed out (ZTS_ETIMEDOUT)';
      case zts_errno_t.ZTS_ECONNREFUSED:
        return 'Connection refused (ZTS_ECONNREFUSED)';
      case zts_errno_t.ZTS_EHOSTUNREACH:
        return 'No route to host (ZTS_EHOSTUNREACH)';
      case zts_errno_t.ZTS_EALREADY:
        return 'Operation already in progress (ZTS_EALREADY)';
      case zts_errno_t.ZTS_EINPROGRESS:
        return 'Operation now in progress (ZTS_EINPROGRESS)';
      default:
        return socketError.toString();
    }
  }

  late final int result;
  late final bool success;

  late final ZtsError errorType;
  late final String? errorMessage;

  late final ZtsSocketError? socketErrorType;
  late final String? socketErrorMessage;

  @override
  String toString() {
    if (success) {
      return 'success';
    }

    if (errorType == ZtsError.socketError) {
      return 'Socket error: $socketErrorMessage';
    }

    return errorMessage!;
  }
}

class ZeroTierResultWithData<T> extends ZeroTierResult {
  ZeroTierResultWithData(super.res, this.data);
  ZeroTierResultWithData.withErrno(super.res, super.errno, this.data);

  final T data;

  @override
  String toString() {
    if (success) {
      return 'success: $data';
    }

    return super.toString();
  }
}

class ZeroTierResultWithData2<T1, T2> extends ZeroTierResult {
  ZeroTierResultWithData2(super.res, this.data1, this.data2);

  final T1 data1;
  final T2 data2;

  @override
  String toString() {
    if (success) {
      return 'success: $data1, $data2';
    }

    return super.toString();
  }
}
