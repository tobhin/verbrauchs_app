import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VerbrauchsDiagramm extends StatelessWidget {
  final Map<int, double> monatsVerbrauch;
  final Color balkenFarbe;
  final String einheit;

  const VerbrauchsDiagramm({
    super.key,
    required this.monatsVerbrauch,
    required this.balkenFarbe,
    required this.einheit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (monatsVerbrauch.isEmpty) {
      return AspectRatio(
        aspectRatio: 1.7,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          child: Center(
            child: Text(
              'Nicht genügend Daten für ein Diagramm vorhanden.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    final List<BarChartGroupData> barGroups = monatsVerbrauch.entries
        .map((entry) => BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value,
                  color: balkenFarbe,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ))
        .toList();

    return AspectRatio(
      aspectRatio: 1.7,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barGroups: barGroups,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final month = value.toInt();
                      final shortMonthName = DateFormat.MMM('de_DE').format(DateTime(0, month));
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(shortMonthName, style: theme.textTheme.bodySmall),
                      );
                    },
                    reservedSize: 28,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Text(value.round().toString(), style: theme.textTheme.bodySmall);
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  // --- KORREKTUR: Die problematische Zeile wurde entfernt, da sie in v0.68.0 nicht existiert ---
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final monthName = DateFormat.MMMM('de_DE').format(DateTime(0, group.x.toInt()));
                    return BarTooltipItem(
                      '$monthName\n',
                      theme.textTheme.bodyLarge!.copyWith(
                        color: Colors.white, // Standard-Textfarbe für dunklen Tooltip
                        fontWeight: FontWeight.bold,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: '${rod.toY.toStringAsFixed(1)} $einheit',
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: Colors.white, // Standard-Textfarbe für dunklen Tooltip
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}