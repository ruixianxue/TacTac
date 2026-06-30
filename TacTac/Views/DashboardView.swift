import SwiftUI
import SwiftData

struct DashboardView: View {
    // 获取上下文，用于前端展示 Mock 数据
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryItem.timeAdded, order: .reverse) private var items: [MemoryItem]
    
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if items.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        ForEach(searchResults) { item in
                            MemoryItemRow(item: item)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Mes Objets")
            .searchable(text: $searchText, prompt: "Rechercher un objet")
            .toolbar {
                // 这个按钮仅供前端调试 UI，不涉及后端真实逻辑
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addMockItem) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    // 搜索过滤逻辑
    var searchResults: [MemoryItem] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { 
                $0.objectName.localizedCaseInsensitiveContains(searchText) || 
                $0.location.localizedCaseInsensitiveContains(searchText) 
            }
        }
    }
    
    // 侧滑删除 UI 反馈
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(searchResults[index])
            }
        }
    }
    
    // 前端一键添加假数据，方便你在 Hackathon 上展示 UI 效果
    private func addMockItem() {
        let newItem = MemoryItem(
            objectName: "Lunettes de vue",
            location: "Table de nuit",
            iconType: "eyeglasses"
        )
        modelContext.insert(newItem)
    }
}

// 提取的空状态组件
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Aucun objet ancré.")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Dites \"Dis Siri, j'ai posé mes clés sur la table.\"")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// 提取的列表行组件
struct MemoryItemRow: View {
    var item: MemoryItem
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: item.iconType)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.objectName)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            
            Text(item.timeAdded, style: .time)
                .font(.caption2)
                .foregroundColor(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
