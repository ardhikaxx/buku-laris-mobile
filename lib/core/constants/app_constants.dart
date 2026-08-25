class Collections {
  Collections._();

  static const users = 'users';
  static const workspaces = 'workspaces';
  static const members = 'members';
  static const products = 'products';
  static const categories = 'categories';
  static const stockMovements = 'stockMovements';
  static const customers = 'customers';
  static const sales = 'sales';
  static const cashTransactions = 'cashTransactions';
  static const paymentMethods = 'paymentMethods';
  static const invitations = 'invitations';
  static const counters = 'counters';
  static const dailySummaries = 'dailySummaries';
  static const auditLogs = 'auditLogs';
  static const notifications = 'notifications';

  static String workspaceDoc(String wsId) => '$workspaces/$wsId';

  static String memberDoc(String wsId, String uid) => '$workspaces/$wsId/$members/$uid';

  static String counterDoc(String wsId, String name) => '$workspaces/$wsId/$counters/$name';

  static String dailySummaryDoc(String wsId, String dayKey) =>
      '$workspaces/$wsId/$dailySummaries/$dayKey';
}

class AppConstants {
  AppConstants._();

  static const appName = 'Buku Laris';
  static const defaultCurrency = 'IDR';
  static const defaultTimezone = 'Asia/Jakarta';
  static const invitationExpiryDays = 7;
  static const pageSize = 20;
  static const maxLogoBytes = 250000;
  static const cascadeBatchSize = 200;
}
