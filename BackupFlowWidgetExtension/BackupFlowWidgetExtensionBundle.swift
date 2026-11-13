import SwiftUI
import WidgetKit

@main
struct BackupFlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        BackupFlowStatusWidget()
        BackupFlowLiveActivityWidget()
    }
}
