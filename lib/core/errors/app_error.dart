/// Noctra Domain & Infrastructure Error Hierarchy
///
/// Provides a unified, type-safe representation of errors across
/// domain, application, infrastructure, and platform layers.
sealed class AppError implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppError(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Domain business rule violations or invariant failures.
class DomainError extends AppError {
  const DomainError(super.message, {super.cause, super.stackTrace});
}

/// Network communication, timeout, or DNS failures.
class NetworkError extends AppError {
  final int? statusCode;
  const NetworkError(super.message, {this.statusCode, super.cause, super.stackTrace});
}

/// Database, file I/O, or cache storage errors.
class StorageError extends AppError {
  const StorageError(super.message, {super.cause, super.stackTrace});
}

/// Native platform channel, permission, or hardware errors.
class PlatformError extends AppError {
  final String? code;
  const PlatformError(super.message, {this.code, super.cause, super.stackTrace});
}

/// Audio decoding, stream resolution, or player engine errors.
class PlaybackError extends AppError {
  final String? trackId;
  const PlaybackError(super.message, {this.trackId, super.cause, super.stackTrace});
}
