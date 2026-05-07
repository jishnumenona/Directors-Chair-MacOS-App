// DirectorsChairProduction/Sources/DirectorsChairProduction/Gantt/GanttDependencyArrows.swift
//
// Canvas overlay drawing dependency arrows between Gantt task bars

import SwiftUI
import DirectorsChairCore

public struct GanttDependencyArrows: View {
    let tasks: [GanttTask]
    let startDate: Date
    let columnWidth: CGFloat
    let rowHeight: CGFloat
    let criticalPath: Set<String>

    private let calendar = Calendar.current
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public init(
        tasks: [GanttTask],
        startDate: Date,
        columnWidth: CGFloat,
        rowHeight: CGFloat,
        criticalPath: Set<String>
    ) {
        self.tasks = tasks
        self.startDate = startDate
        self.columnWidth = columnWidth
        self.rowHeight = rowHeight
        self.criticalPath = criticalPath
    }

    public var body: some View {
        Canvas { context, size in
            let taskIndexMap = Dictionary(uniqueKeysWithValues: tasks.enumerated().map { ($1.id, $0) })

            for task in tasks {
                guard let taskRow = taskIndexMap[task.id] else { continue }

                for depId in task.dependsOn {
                    guard let depRow = taskIndexMap[depId],
                          let dep = tasks.first(where: { $0.id == depId }) else { continue }

                    let isCriticalArrow = criticalPath.contains(task.id) && criticalPath.contains(depId)

                    // Source: end of dependency bar
                    let depEndX = xPosition(for: dep.computedEndDate) + columnWidth
                    let depY = CGFloat(depRow) * rowHeight + rowHeight / 2

                    // Target: start of task bar
                    let taskStartX = xPosition(for: task.startDate)
                    let taskY = CGFloat(taskRow) * rowHeight + rowHeight / 2

                    // Draw bezier arrow
                    var path = Path()
                    path.move(to: CGPoint(x: depEndX, y: depY))

                    let midX = (depEndX + taskStartX) / 2
                    if abs(depY - taskY) < 2 {
                        // Same row — straight line
                        path.addLine(to: CGPoint(x: taskStartX - 4, y: taskY))
                    } else {
                        // Curve from end to start
                        path.addCurve(
                            to: CGPoint(x: taskStartX - 4, y: taskY),
                            control1: CGPoint(x: midX, y: depY),
                            control2: CGPoint(x: midX, y: taskY)
                        )
                    }

                    let strokeColor: Color = isCriticalArrow ? .accentColor : Color(nsColor: .tertiaryLabelColor)
                    let lineWidth: CGFloat = isCriticalArrow ? 1.5 : 1

                    context.stroke(path, with: .color(strokeColor), lineWidth: lineWidth)

                    // Arrowhead
                    var arrowHead = Path()
                    let tip = CGPoint(x: taskStartX - 1, y: taskY)
                    arrowHead.move(to: tip)
                    arrowHead.addLine(to: CGPoint(x: tip.x - 5, y: tip.y - 3))
                    arrowHead.addLine(to: CGPoint(x: tip.x - 5, y: tip.y + 3))
                    arrowHead.closeSubpath()
                    context.fill(arrowHead, with: .color(strokeColor))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func xPosition(for dateString: String) -> CGFloat {
        guard let date = Self.dateFormatter.date(from: dateString) else { return 0 }
        let days = calendar.dateComponents([.day], from: startDate, to: date).day ?? 0
        return CGFloat(days) * columnWidth
    }
}
