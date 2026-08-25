import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/audit_notification_repository.dart';
import '../repositories/cashflow_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../repositories/invitation_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/sale_repository.dart';
import '../repositories/stock_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/workspace_repository.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final userRepositoryProvider =
    Provider<UserRepository>((ref) => UserRepository());

final workspaceRepositoryProvider =
    Provider<WorkspaceRepository>((ref) => WorkspaceRepository());

final membershipRepositoryProvider =
    Provider<MembershipRepository>((ref) => MembershipRepository());

final invitationRepositoryProvider =
    Provider<InvitationRepository>((ref) => InvitationRepository());

final productRepositoryProvider =
    Provider<ProductRepository>((ref) => ProductRepository());

final categoryRepositoryProvider =
    Provider<CategoryRepository>((ref) => CategoryRepository());

final stockRepositoryProvider =
    Provider<StockRepository>((ref) => StockRepository());

final customerRepositoryProvider =
    Provider<CustomerRepository>((ref) => CustomerRepository());

final saleRepositoryProvider =
    Provider<SaleRepository>((ref) => SaleRepository());

final cashflowRepositoryProvider =
    Provider<CashflowRepository>((ref) => CashflowRepository());

final dashboardRepositoryProvider =
    Provider<DashboardRepository>((ref) => DashboardRepository());

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository());

final auditRepositoryProvider =
    Provider<AuditRepository>((ref) => AuditRepository());
