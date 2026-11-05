import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../app/theme/app_colors.dart';
import '../../features/messages/presentation/providers/messages_providers.dart';

/// Persistent 5-tab navigation shell for authenticated routes:
/// 0: Khám phá (`/home`)
/// 1: Blog (`/blogs`)
/// 2: Đăng bán (`/create-listing`)
/// 3: Tin nhắn (`/messages`)
/// 4: Hồ sơ (`/profile`)
/// Plus a draggable circular AI Assistant button (`_DraggableAiBubble`) overlaid on screen.
class MainShellScaffold extends ConsumerStatefulWidget {
  const MainShellScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShellScaffold> createState() => _MainShellScaffoldState();
}

class _MainShellScaffoldState extends ConsumerState<MainShellScaffold> {
  // Relative position (null until initialized from screen size, defaults to bottom-right)
  Offset? _bubbleOffset;

  void _onDestinationSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Widget _buildMessagesNavIcon(
    IconData iconData, {
    required bool hasUnread,
    required int unreadCount,
    Color? iconColor,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Icon(iconData, color: iconColor),
        if (hasUnread)
          Positioned(
            right: -5,
            top: -4,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: unreadCount > 9 ? 4 : 5,
                vertical: 1.5,
              ),
              constraints: const BoxConstraints(
                minWidth: 12,
                minHeight: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.surface,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final convState = ref.watch(conversationsControllerProvider);
    final hasUnreadMessages = convState.hasUnread;
    final unreadMessagesCount = convState.totalUnreadCount;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          const bubbleSize = 58.0;
          const margin = 14.0;
          final maxW = constraints.maxWidth;
          final maxH = constraints.maxHeight;

          final defaultX = (maxW - bubbleSize - margin).clamp(margin, maxW);
          final defaultY = (maxH - bubbleSize - 88.0).clamp(margin, maxH);

          final currentOffset = _bubbleOffset ?? Offset(defaultX, defaultY);
          final clampedX = currentOffset.dx.clamp(
            margin,
            (maxW - bubbleSize - margin).clamp(margin, maxW),
          );
          final clampedY = currentOffset.dy.clamp(
            margin,
            (maxH - bubbleSize - margin).clamp(margin, maxH),
          );

          return Stack(
            children: [
              widget.navigationShell,
              Positioned(
                left: clampedX,
                top: clampedY,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      final nextX = (clampedX + details.delta.dx).clamp(
                        margin,
                        (maxW - bubbleSize - margin).clamp(margin, maxW),
                      );
                      final nextY = (clampedY + details.delta.dy).clamp(
                        margin,
                        (maxH - bubbleSize - margin).clamp(margin, maxH),
                      );
                      _bubbleOffset = Offset(nextX, nextY);
                    });
                  },
                  onPanEnd: (_) {
                    // Snap horizontally to nearest left/right edge for clean UX
                    final midX = maxW / 2;
                    final targetX = (clampedX + bubbleSize / 2) < midX
                        ? margin
                        : (maxW - bubbleSize - margin).clamp(margin, maxW);
                    setState(() {
                      _bubbleOffset = Offset(targetX, clampedY);
                    });
                  },
                  onTap: () => context.push(RouteNames.aiChatPath),
                  child: Tooltip(
                    message: 'Trợ lý Mua sắm Gemini AI (Kéo để di chuyển)',
                    child: Container(
                      width: bubbleSize,
                      height: bubbleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryDark,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: Colors.white,
                          width: 2.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.38),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(height: 1),
                          Text(
                            'AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryTintBg,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(
              Icons.explore_rounded,
              color: AppColors.primary,
            ),
            label: 'Khám phá',
          ),
          const NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(
              Icons.article_rounded,
              color: AppColors.primary,
            ),
            label: 'Blog',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(
              Icons.add_box_rounded,
              color: AppColors.primary,
            ),
            label: 'Đăng bán',
          ),
          NavigationDestination(
            icon: _buildMessagesNavIcon(
              Icons.chat_bubble_outline_rounded,
              hasUnread: hasUnreadMessages,
              unreadCount: unreadMessagesCount,
            ),
            selectedIcon: _buildMessagesNavIcon(
              Icons.chat_bubble_rounded,
              hasUnread: hasUnreadMessages,
              unreadCount: unreadMessagesCount,
              iconColor: AppColors.primary,
            ),
            label: 'Tin nhắn',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(
              Icons.person_rounded,
              color: AppColors.primary,
            ),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}
