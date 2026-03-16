import SwiftUI

struct VaultHomeView: View {
    @Bindable var model: LatchAppModel

    @State private var selectedItem: VaultItem?
    @State private var presentingNewEntry = false
    @State private var editingItem: VaultItem?

    var body: some View {
        NavigationStack {
            AppScrollView {
                favoritesSection
                allItemsSection
            }
            .navigationTitle("Latch")
            .searchable(text: $model.searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.lockNow()
                    } label: {
                        Image(systemName: "lock.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentingNewEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $selectedItem) { item in
                VaultItemDetailView(
                    model: model,
                    item: item,
                    onEdit: {
                        editingItem = item
                        selectedItem = nil
                    }
                )
            }
            .sheet(isPresented: $presentingNewEntry) {
                VaultEntryEditorView(model: model, editingItem: nil)
            }
            .sheet(item: $editingItem, onDismiss: {
                editingItem = nil
            }) { item in
                VaultEntryEditorView(model: model, editingItem: item)
            }
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LatchSectionHeader(
                eyebrow: nil,
                title: "Favorite Accounts",
                detail: nil
            )

            if model.favoriteItems.isEmpty {
                EmptyStateCard(
                    title: "No favorites yet",
                    detail: "Mark entries as favorites when you create or edit them.",
                    systemImage: "star"
                )
            } else {
                ForEach(model.favoriteItems) { item in
                    VaultItemRow(model: model, item: item)
                        .onTapGesture {
                            selectedItem = item
                        }
                }
            }
        }
    }

    private var allItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LatchSectionHeader(
                eyebrow: nil,
                title: model.searchText.isEmpty ? "All Entries" : "Search Results",
                detail: nil
            )

            if model.filteredVaultItems.isEmpty {
                EmptyStateCard(
                    title: model.searchText.isEmpty ? "Your vault is empty" : "Nothing matched your search",
                    detail: model.searchText.isEmpty
                        ? "Add your first credential with the plus button in the top-right corner."
                        : "Try a service name, account identifier, or tag.",
                    systemImage: model.searchText.isEmpty ? "plus.circle" : "magnifyingglass"
                )
            } else {
                ForEach(model.filteredVaultItems) { item in
                    VaultItemRow(model: model, item: item)
                        .onTapGesture {
                            selectedItem = item
                        }
                }
            }
        }
    }
}

private struct VaultItemRow: View {
    @Bindable var model: LatchAppModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.latchAccentPalette) private var accentPalette

    let item: VaultItem

    var body: some View {
        let strength = model.passwordStrength(for: item)

        SurfaceCard {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.secondaryCardFill(for: colorScheme))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: item.hasTOTP ? "lock.badge.clock" : "lock")
                            .font(.title3)
                            .foregroundStyle(accentPalette.color)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.service)
                            .font(.headline)
                            .lineLimit(1)
                        Spacer()
                        StatusPill(title: strength.title, tone: strengthTone(strength))
                    }

                    Text(item.username)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !item.notes.isEmpty {
                        Text(item.notes)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    HStack {
                        Label("Password in Keychain", systemImage: "key.fill")
                        Spacer()
                        if item.hasTOTP, let snapshot = model.totpSnapshot(for: item) {
                            StatusPill(title: snapshot.code, tone: .accent)
                        } else {
                            StatusPill(title: "2FA not set", tone: .warning)
                        }
                    }
                    .font(.caption.weight(.medium))

                    if !item.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(item.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(AppTheme.secondaryCardFill(for: colorScheme))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
        }
    }

    private func strengthTone(_ strength: PasswordStrength) -> StatusPill.Tone {
        switch strength {
        case .strong:
            .success
        case .good:
            .warning
        case .needsAttention:
            .danger
        }
    }
}
