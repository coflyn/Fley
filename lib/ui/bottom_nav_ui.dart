// ignore_for_file: invalid_use_of_protected_member
part of '../main.dart';

extension _BottomNavUI on _MainScreenState {
  Widget _buildBottomNavBar() {
    final isLight = isAppLight;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final activeColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;
    final inactiveColor = isLight ? Colors.black38 : Colors.white54;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: 60 + bottomInset,
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: BoxDecoration(
              color: (isLight ? const Color(0xFFFFFFFF) : const Color(0xFF0F0F12))
                  .withValues(alpha: 0.94),
              border: Border(
                top: BorderSide(
                  color: (isLight ? Colors.black : Colors.white)
                      .withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: _currentNavIndex == 0
                      ? Icons.home
                      : Icons.home_outlined,
                  label: AppLocalizations.of(context).home,
                  isSelected: _currentNavIndex == 0,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
                _buildNavItem(
                  index: 1,
                  icon: _currentNavIndex == 1
                      ? Icons.search
                      : Icons.search_rounded,
                  label: AppLocalizations.of(context).search,
                  isSelected: _currentNavIndex == 1,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
                _buildNavItem(
                  index: 2,
                  icon: _currentNavIndex == 2
                      ? Icons.library_music_rounded
                      : Icons.library_music_outlined,
                  label: AppLocalizations.of(context).library,
                  isSelected: _currentNavIndex == 2,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          _switchToNavTab(index);
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                fontFamily: getFontFamily(activeFontNotifier.value),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
