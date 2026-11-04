import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/call_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/call_repository.dart';
import '../../services/presence_service.dart';
import '../chats/chats_tab.dart';
import '../calls/calls_tab.dart';
import '../contacts/contacts_tab.dart';
import '../profile/profile_tab.dart';
import '../calls/incoming_call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final PresenceService _presenceService = PresenceService();
  final CallRepository _callRepository = CallRepository();

  StreamSubscription<CallModel?>? _incomingCallSub;
  bool _isCallModalShowing = false;

  final List<Widget> _tabs = const [
    ChatsTab(),
    CallsTab(),
    ContactsTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupPresenceAndCallListener();
  }

  void _setupPresenceAndCallListener() {
    final authRepo = Provider.of<AuthRepository>(context, listen: false);
    final uid = authRepo.currentUid;
    if (uid != null) {
      // Mark online
      _presenceService.setOnlineStatus(uid, true);

      // Listen for incoming WebRTC calls in real-time
      _incomingCallSub = _callRepository.streamIncomingCalls(uid).listen((call) {
        if (call != null && !_isCallModalShowing && mounted) {
          _isCallModalShowing = true;
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => IncomingCallScreen(call: call),
                ),
              )
              .then((_) {
            _isCallModalShowing = false;
          });
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = Provider.of<AuthRepository>(context, listen: false).currentUid;
    if (uid != null) {
      if (state == AppLifecycleState.resumed) {
        _presenceService.setOnlineStatus(uid, true);
      } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
        _presenceService.setOnlineStatus(uid, false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _incomingCallSub?.cancel();
    _pageController.dispose();
    _presenceService.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        physics: const NeverScrollableScrollPhysics(), // tab navigation only
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(
            top: BorderSide(color: Color(0xFF1E1E1E), width: 0.8),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: Colors.transparent,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                );
              }
              return const TextStyle(color: AppColors.igMutedGrey, fontSize: 11);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Colors.white, size: 26);
              }
              return const IconThemeData(color: AppColors.igMutedGrey, size: 24);
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabSelected,
            backgroundColor: Colors.transparent,
            elevation: 0,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.send_outlined),
                selectedIcon: Icon(Icons.send_rounded),
                label: 'Direct',
              ),
              NavigationDestination(
                icon: Icon(Icons.videocam_outlined),
                selectedIcon: Icon(Icons.videocam_rounded),
                label: 'Calls',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline_rounded),
                selectedIcon: Icon(Icons.people_rounded),
                label: 'Contacts',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
