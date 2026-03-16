import 'package:flutter/material.dart';

Future<DateTime?> showScribeDatePicker(BuildContext context, DateTime currentSelectedDate) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  // Scribe Design System Colors
  final Color bgColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
  final Color textPrimary = isDark ? const Color(0xFFE1E1E1) : const Color(0xFF1A1A1A);
  final Color textSecondary = isDark ? const Color(0xFFAAAAAA) : const Color(0xFF6B6B6B);
  const Color scribeTeal = Color(0xFF1A8C7E);

  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: bgColor,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      bool showMonthYearPicker = false;
      DateTime viewMonth = DateTime(currentSelectedDate.year, currentSelectedDate.month);
      DateTime selectedDate = currentSelectedDate;

      return StatefulBuilder(
        builder: (context, setState) {
          final int daysInMonth = DateTime(viewMonth.year, viewMonth.month + 1, 0).day;
          final int firstWeekday = DateTime(viewMonth.year, viewMonth.month, 1).weekday;
          final List<String> monthNames = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
          
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Bottom Sheet Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Month & Year Header with Navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          showMonthYearPicker = !showMonthYearPicker;
                        });
                      },
                      child: Row(
                        children: [
                          Text(
                            showMonthYearPicker 
                                ? '${viewMonth.year}' 
                                : '${monthNames[viewMonth.month - 1]} ${viewMonth.year}',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            showMonthYearPicker ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, 
                            color: scribeTeal, 
                            size: 20
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, color: textSecondary),
                          onPressed: () {
                            setState(() {
                              if (showMonthYearPicker) {
                                viewMonth = DateTime(viewMonth.year - 1, viewMonth.month);
                              } else {
                                viewMonth = DateTime(viewMonth.year, viewMonth.month - 1);
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: textSecondary),
                          onPressed: () {
                            setState(() {
                              if (showMonthYearPicker) {
                                viewMonth = DateTime(viewMonth.year + 1, viewMonth.month);
                              } else {
                                viewMonth = DateTime(viewMonth.year, viewMonth.month + 1);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (showMonthYearPicker) ...[
                  // Month Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      bool isSelectedMonth = (index + 1) == viewMonth.month;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            viewMonth = DateTime(viewMonth.year, index + 1);
                            showMonthYearPicker = false;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelectedMonth ? scribeTeal : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelectedMonth ? null : Border.all(color: isDark ? Colors.white10 : Colors.black12),
                          ),
                          child: Center(
                            child: Text(
                              monthNames[index].substring(0, 3), // Short name
                              style: TextStyle(
                                color: isSelectedMonth ? Colors.white : textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  // 3. Weekday Labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'].map((day) {
                      return Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 4. Calendar Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: 42,
                    itemBuilder: (context, index) {
                      final int dayOffset = index - (firstWeekday - 1);
                      if (dayOffset < 0 || dayOffset >= daysInMonth) {
                        return const SizedBox.shrink();
                      }
                      int day = dayOffset + 1;
                      bool isSelected = selectedDate.year == viewMonth.year && 
                                        selectedDate.month == viewMonth.month && 
                                        selectedDate.day == day;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedDate = DateTime(viewMonth.year, viewMonth.month, day);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? scribeTeal : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: isSelected ? Colors.white : textPrimary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 32),

                // 5. Action Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, selectedDate),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scribeTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Select',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

