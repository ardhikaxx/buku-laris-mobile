import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/invitation_model.dart';
import '../models/user_profile_model.dart';
import '../models/workspace_member_model.dart';
import '../models/workspace_model.dart';
import '../repositories/membership_repository.dart';
import 'providers.dart';

enum GateStatus { loading, signedOut, needsOnboarding, hasInvitations, ready }

class GateState {
  final GateStatus status;
  final User? user;
  final UserProfile? profile;
  final List<Invitation> pendingInvitations;
  final String? activeWorkspaceId;
  final WorkspaceMember? myMembership;

  const GateState({
    required this.status,
    this.user,
    this.profile,
    this.pendingInvitations = const [],
    this.activeWorkspaceId,
    this.myMembership,
  });

  bool get isOwner => myMembership?.isOwner ?? false;
}

class GateController extends Notifier<GateState> {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<UserProfile?>? _profileSub;
  StreamSubscription<List<Invitation>>? _inviteSub;

  UserProfile? _profile;
  List<Invitation> _invites = [];
  Map<String, WorkspaceMember> _memberships = {};
  bool _profileLoaded = false;
  bool _invitesLoaded = false;
  String? _ensuringProfileFor;

  @override
  GateState build() {
    ref.onDispose(_teardown);
    _authSub?.cancel();
    _authSub =
        ref.read(authServiceProvider).authStateChanges.listen(_onUserChanged);
    return const GateState(status: GateStatus.loading);
  }

  void _teardown() {
    _authSub?.cancel();
    _profileSub?.cancel();
    _inviteSub?.cancel();
  }

  Future<void> _onUserChanged(User? user) async {
    await _profileSub?.cancel();
    await _inviteSub?.cancel();
    _profile = null;
    _invites = [];
    _memberships = {};
    _profileLoaded = false;
    _invitesLoaded = false;

    if (user == null) {
      state = const GateState(status: GateStatus.signedOut);
      return;
    }
    state = GateState(status: GateStatus.loading, user: user);

    final userRepo = ref.read(userRepositoryProvider);
    final inviteRepo = ref.read(invitationRepositoryProvider);
    final memberRepo = ref.read(membershipRepositoryProvider);

    if (_ensuringProfileFor != user.uid) {
      _ensuringProfileFor = user.uid;
      try {
        await userRepo.ensureProfile(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
          photoUrl: user.photoURL,
        );
      } catch (_) {}
    }

    await _profileSub?.cancel();
    _profileSub = userRepo.watchByUid(user.uid).listen((profile) {
      _profile = profile;
      _profileLoaded = true;
      _refreshMemberships(memberRepo, user.uid);
      state = _derive();
    }, onError: (_) {
      _profileLoaded = true;
      state = _derive();
    });

    if ((user.email ?? '').isNotEmpty) {
      await _inviteSub?.cancel();
      _invitesLoaded = false;
      _inviteSub = inviteRepo
          .listPendingForEmail(user.email!)
          .asStream()
          .listen((invites) {
        _invites = invites;
        _invitesLoaded = true;
        state = _derive();
      }, onError: (_) {
        _invitesLoaded = true;
        state = _derive();
      });
    } else {
      _invitesLoaded = true;
    }
  }

  void _refreshMemberships(MembershipRepository memberRepo, String uid) async {
    final ids = _profile?.workspaceIds ?? [];
    if (ids.isEmpty) {
      _memberships = {};
      state = _derive();
      return;
    }
    final map = <String, WorkspaceMember>{};
    for (final wsId in ids) {
      try {
        final member = await memberRepo.getMember(wsId, uid);
        if (member != null && member.isActive) map[wsId] = member;
      } catch (_) {}
    }
    _memberships = map;
    state = _derive();
  }

  GateState _derive() {
    final user = FirebaseAuth.instance.currentUser;
    if (!_profileLoaded || !_invitesLoaded) {
      return GateState(status: GateStatus.loading, user: user);
    }
    if (_profile == null) {
      return GateState(status: GateStatus.loading, user: user);
    }
    if (_invites.isNotEmpty) {
      return GateState(
        status: GateStatus.hasInvitations,
        user: user,
        profile: _profile,
        pendingInvitations: _invites,
        activeWorkspaceId: null,
        myMembership: null,
      );
    }
    final activeIds =
        _memberships.keys.toList(growable: false);
    if (activeIds.isEmpty) {
      return GateState(
        status: GateStatus.needsOnboarding,
        user: user,
        profile: _profile,
        activeWorkspaceId: null,
      );
    }
    final preferred = _profile!.activeWorkspaceId;
    final chosen =
        (preferred != null && _memberships.containsKey(preferred))
            ? preferred
            : activeIds.first;
    return GateState(
      status: GateStatus.ready,
      user: user,
      profile: _profile,
      activeWorkspaceId: chosen,
      myMembership: _memberships[chosen],
    );
  }

  void switchWorkspace(String workspaceId) {
    final profile = _profile;
    if (profile == null) return;
    if (!_memberships.containsKey(workspaceId)) return;
    ref.read(userRepositoryProvider).setActiveWorkspace(profile.uid, workspaceId);
  }

  void refreshAfterInvitationResolved() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _onUserChanged(user);
  }
}

final gateProvider =
    NotifierProvider<GateController, GateState>(GateController.new);

class ActiveWorkspaceState {
  final Workspace? workspace;
  final WorkspaceMember? member;
  final bool loading;
  final String? error;

  const ActiveWorkspaceState({
    this.workspace,
    this.member,
    this.loading = false,
    this.error,
  });

  bool get isOwner => member?.role == UserRole.OWNER;

  bool can(Permission permission) => member?.hasPermission(permission) ?? false;
}

final activeWorkspaceProvider =
    NotifierProvider<ActiveWorkspaceController, ActiveWorkspaceState>(
        ActiveWorkspaceController.new);

class ActiveWorkspaceController extends Notifier<ActiveWorkspaceState> {
  StreamSubscription<Workspace?>? _wsSub;

  @override
  ActiveWorkspaceState build() {
    ref.onDispose(() => _wsSub?.cancel());
    final gate = ref.watch(gateProvider);
    final wsId = gate.activeWorkspaceId;
    if (wsId == null) {
      return const ActiveWorkspaceState();
    }
    _wsSub = ref
        .read(workspaceRepositoryProvider)
        .watch(wsId)
        .listen((workspace) {
      state = ActiveWorkspaceState(
        workspace: workspace,
        member: gate.myMembership,
      );
    });
    return ActiveWorkspaceState(
      member: gate.myMembership,
      loading: true,
    );
  }
}
