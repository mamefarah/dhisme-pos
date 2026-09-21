import 'package:dhisme_pos/features/auth/models/app_profile.dart';
import 'package:flutter_test/flutter_test.dart';

AppProfile _profile(String role) => AppProfile(
      id: 'u1',
      storeId: 's1',
      fullName: 'Test User',
      role: role,
    );

void main() {
  group('AppProfile permission getters (drive SettingsScreen visibility)', () {
    test('owner can edit store settings, manage employees, decide approvals, review closings, view reports', () {
      final owner = _profile('owner');
      expect(owner.canEditStoreSettings, isTrue, reason: 'Owner Settings must show editable Store Settings');
      expect(owner.canManageEmployees, isTrue);
      expect(owner.canDecideApprovals, isTrue);
      expect(owner.canReviewCashClosings, isTrue);
      expect(owner.canViewReports, isTrue, reason: 'Owner must still access Reports');
    });

    test('manager cannot edit store settings, manage employees, decide approvals, or review closings', () {
      final manager = _profile('manager');
      expect(manager.canEditStoreSettings, isFalse, reason: 'Manager Settings must NOT expose editable Store Settings');
      expect(manager.canManageEmployees, isFalse, reason: 'Manager must not navigate to Employees/Invites');
      expect(manager.canDecideApprovals, isFalse, reason: 'Manager must not reach approval-decision controls');
      expect(manager.canReviewCashClosings, isFalse, reason: 'Manager must not reach closing-review controls');
    });

    test('manager can view reports (backend RPCs already authorize owner/manager)', () {
      expect(_profile('manager').canViewReports, isTrue);
    });

    test('seller has no owner/manager administrative or reporting access', () {
      final seller = _profile('seller');
      expect(seller.canEditStoreSettings, isFalse);
      expect(seller.canManageEmployees, isFalse);
      expect(seller.canDecideApprovals, isFalse);
      expect(seller.canReviewCashClosings, isFalse);
      expect(seller.canViewReports, isFalse, reason: 'Seller Settings must not expose owner/manager administrative or reporting items');
    });
  });

  group('AppProfile role flags (drive AuthGate routing to Owner/Manager/SellerHomeScreen)', () {
    test('owner role routes to OwnerHomeScreen', () {
      final owner = _profile('owner');
      expect(owner.isOwner, isTrue);
      expect(owner.isManager, isFalse);
      expect(owner.isSeller, isFalse);
    });

    test('manager role routes to ManagerHomeScreen', () {
      final manager = _profile('manager');
      expect(manager.isOwner, isFalse);
      expect(manager.isManager, isTrue);
      expect(manager.isSeller, isFalse);
    });

    test('seller role routes to SellerHomeScreen', () {
      final seller = _profile('seller');
      expect(seller.isOwner, isFalse);
      expect(seller.isManager, isFalse);
      expect(seller.isSeller, isTrue);
    });
  });
}
