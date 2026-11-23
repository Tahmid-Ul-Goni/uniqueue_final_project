/// Central English copy for repeated queue and system states.
/// Keep screen-specific explanatory copy short and move it here as flows evolve.
class UniQueueStrings {
  UniQueueStrings._();

  static const appName = 'UniQueue';
  static const retry = 'Retry';
  static const back = 'Back';
  static const logOut = 'Log out';
  static const noConnection =
      'No connection. Showing the last available queue data.';
  static const connectionRetry = 'Check your connection and try again.';
  static const loading = 'Loading';
  static const emptyQueue = 'No one waiting';
  static const statusWaiting = 'Waiting';
  static const statusApproaching = 'Approaching';
  static const statusServing = 'Serving';
  static const statusOnHold = 'On Hold';
  static const statusCompleted = 'Completed';
  static const statusCancelled = 'Cancelled';
  static const statusExpired = 'Expired';
  static const tokenCreated = 'You are in the queue';
  static const tokenAlreadyActive =
      'You already have an active token for this service.';
  static const invalidQr =
      'This token is not valid. Ask the student to open the latest token.';
  static const wrongDepartment =
      'This token belongs to another counter. Select the matching department.';
  static const tokenExpired =
      'This token expired or was cancelled. Ask the student to get a new token.';
}
