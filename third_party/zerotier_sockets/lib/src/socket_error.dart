/// Socket error codes returned by libzt
enum ZtsSocketError {
  /// Operation not permitted (ZTS_EPERM)
  eperm,

  /// No such file or directory (ZTS_ENOENT)
  enoent,

  /// No such process (ZTS_ESRCH)
  esrch,

  /// Interrupted system call (ZTS_EINTR)
  eintr,

  /// I/O error (ZTS_EIO)
  eio,

  /// No such device or address (ZTS_ENXIO)
  enxio,

  /// Bad file number (ZTS_EBADF)
  ebadf,

  /// Try again (ZTS_EAGAIN)
  eagain,

  /// Operation would block (ZTS_EWOULDBLOCK)
  ewouldblock,

  /// Out of memory (ZTS_ENOMEM)
  enomem,

  /// Permission denied (ZTS_EACCES)
  eacces,

  /// Bad address (ZTS_EFAULT)
  efault,

  /// Device or resource busy (ZTS_EBUSY)
  ebusy,

  /// File exists (ZTS_EEXIST)
  eexist,

  /// No such device (ZTS_ENODEV)
  enodev,

  /// Invalid argument (ZTS_EINVAL)
  einval,

  /// File table overflow (ZTS_ENFILE)
  enfile,

  /// Too many open files (ZTS_EMFILE)
  emfile,

  /// Function not implemented (ZTS_ENOSYS)
  enosys,

  /// Socket operation on non-socket (ZTS_ENOTSOCK)
  enotsock,

  /// Destination address required (ZTS_EDESTADDRREQ)
  edestaddrreq,

  /// Message too long (ZTS_EMSGSIZE)
  emsgsize,

  /// Protocol wrong type for socket (ZTS_EPROTOTYPE)
  eprototype,

  /// Protocol not available (ZTS_ENOPROTOOPT)
  enoprotoopt,

  /// Protocol not supported (ZTS_EPROTONOSUPPORT)
  eprotonosupport,

  /// Socket type not supported (ZTS_ESOCKTNOSUPPORT)
  esocktnosupport,

  /// Operation not supported on transport endpoint (ZTS_EOPNOTSUPP)
  eopnotsupp,

  /// Protocol family not supported (ZTS_EPFNOSUPPORT)
  epfnosupport,

  /// Address family not supported by protocol (ZTS_EAFNOSUPPORT)
  eafnosupport,

  /// Address already in use (ZTS_EADDRINUSE)
  eaddrinuse,

  /// Cannot assign requested address (ZTS_EADDRNOTAVAIL)
  eaddrnotavail,

  /// Network is down (ZTS_ENETDOWN)
  enetdown,

  /// Network is unreachable (ZTS_ENETUNREACH)
  enetunreach,

  /// Network dropped connection because of reset (ZTS_ENETRESET)
  enetreset,

  /// Software caused connection abort (ZTS_ECONNABORTED)
  econnaborted,

  /// Connection reset by peer (ZTS_ECONNRESET)
  econnreset,

  /// No buffer space available (ZTS_ENOBUFS)
  enobufs,

  /// Transport endpoint is already connected (ZTS_EISCONN)
  eisconn,

  /// Transport endpoint is not connected (ZTS_ENOTCONN)
  enotconn,

  /// Connection timed out (ZTS_ETIMEDOUT)
  etimedout,

  /// Connection refused (ZTS_ECONNREFUSED)
  econnrefused,

  /// No route to host (ZTS_EHOSTUNREACH)
  ehostunreach,

  /// Operation already in progress (ZTS_EALREADY)
  ealready,

  /// Operation now in progress (ZTS_EINPROGRESS)
  einprogress,
}
