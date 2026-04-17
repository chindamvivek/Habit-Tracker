import 'package:flutter/material.dart';

class DateCard extends StatelessWidget {
  final int date;
  final bool isToday;
  final bool isSelected;
  final bool isPast;
  final VoidCallback onTap;
  final Color? containerColor;
  final double completionRatio; // 0.0 to 1.0

  const DateCard({
    super.key,
    required this.date,
    this.isToday = false,
    this.isSelected = false,
    this.isPast = false,
    required this.onTap,
    this.containerColor,
    this.completionRatio = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Determine colors based on state, NOT hex values
    Color circleColor;
    Color textColor;

    if (completionRatio >= 1.0) {
      // Fully completed - use primary brand color
      circleColor = colorScheme.primary;
      textColor = colorScheme.onPrimary;
    } else if (isToday) {
      // Today (incomplete) - neutral gray indicator
      // Using opacity to ensure it works on both Light and Dark modes
      circleColor = colorScheme.onSurface.withValues(alpha: 0.3);
      textColor = colorScheme.onSurface; // Text inside the gray circle
    } else {
      // Default - transparent background
      circleColor = Colors.transparent;
      textColor = colorScheme.onSurface;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: containerColor ?? Colors.transparent,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Date circle with optional progress ring
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Date circle
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: circleColor,
                    ),
                    child: Center(
                      child: Text(
                        "$date",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),

                  // Progress ring (partial completion only) - Now on top
                  if (completionRatio > 0.0 && completionRatio < 1.0)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: completionRatio,
                        strokeWidth: 4.0,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Spacing to prevent overlap
            const SizedBox(height: 8),

            // Selection underline
            if (isSelected)
              Container(
                width: 24,
                height: 3,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
