/// Explicit outcome states for Assistant commands to report accurate status
/// back to Android / Google Assistant without throwing uncaught exceptions.
sealed class AssistantResult {
  final String message;
  const AssistantResult([this.message = '']);

  bool get isSuccess => this is AssistantSuccess;
}

class AssistantSuccess extends AssistantResult {
  final dynamic data;
  const AssistantSuccess([this.data, super.message = 'Success']);
}

class AssistantNotFound extends AssistantResult {
  const AssistantNotFound([super.message = 'Item not found']);
}

class AssistantAmbiguous extends AssistantResult {
  final List<String> candidates;
  const AssistantAmbiguous(this.candidates, [super.message = 'Multiple candidates match']);
}

class AssistantUnavailableOffline extends AssistantResult {
  const AssistantUnavailableOffline([super.message = 'Item is not available offline']);
}

class AssistantNetworkFailure extends AssistantResult {
  const AssistantNetworkFailure([super.message = 'Network connection failure']);
}

class AssistantUnsupported extends AssistantResult {
  const AssistantUnsupported([super.message = 'Action is not supported by platform']);
}

class AssistantPermissionDenied extends AssistantResult {
  const AssistantPermissionDenied([super.message = 'Permission denied']);
}

class AssistantInvalidCommand extends AssistantResult {
  const AssistantInvalidCommand([super.message = 'Invalid or malformed command']);
}

class AssistantInternalFailure extends AssistantResult {
  final Object? error;
  const AssistantInternalFailure(this.error, [super.message = 'Internal failure']);
}
