import SwiftUI

struct ScheduleListView: View {
    @Binding var scheduleGroups: [ScheduleGroup]
    @Binding var selectedGroup: ScheduleGroup?
    
    var body: some View {
        List {
            ForEach($scheduleGroups) { $group in
                HStack(spacing: 16) {
                    // Color Indicator
                    Circle()
                        .fill(group.color)
                        .frame(width: 12, height: 12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.headline)
                            .foregroundColor(group.isActive ? .white : .white.opacity(0.5))
                        
                        Text(group.summary)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text(group.time.formatted(date: .omitted, time: .shortened))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(group.color.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $group.isActive)
                        .labelsHidden()
                        .tint(group.color)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .listRowBackground(Color.white.opacity(0.05))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteGroup(group.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .onTapGesture {
                    selectedGroup = group
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private func deleteGroup(_ id: UUID) {
        withAnimation {
            scheduleGroups.removeAll { $0.id == id }
        }
    }
}
