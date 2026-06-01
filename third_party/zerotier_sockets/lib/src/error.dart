/// Errors returned by libzt
enum ZtsError {
  /// No error (ZTS_ERR_OK)
  none,

  /// Socket error (ZTS_ERR_SOCKET)
  socketError,

  /// The node service experienced a problem (ZTS_ERR_SERVICE)
  nodeServiceError,

  /// Invalid argument (ZTS_ERR_ARG)
  invalidArgument,

  /// No result (not necessarily an error) (ZTS_ERR_NO_RESULT)
  noResult,

  /// Consider filing a bug report (ZTS_ERR_GENERAL)
  generalError
}
