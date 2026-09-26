import SwiftUI
import AppKit
import GDCPluginManagerCore

struct CoursesGrid: View {
    let courses: [Course]

    // Mai lat decât înainte (260→300): cardurile au acum copertă și
    // descrierea se vede întreagă, deci au nevoie de spațiu ca să nu se
    // înghesuie textul pe rânduri de 3 cuvinte.
    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: GDCTokens.Space.l)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `courses`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: courses, options: .content) { courses in
        ScrollView {
            if courses.isEmpty {
                Text(L.t("courses.empty")).foregroundStyle(.secondary).padding(GDCTokens.Space.page)
            } else {
                LazyVGrid(columns: columns, spacing: GDCTokens.Space.grid) {
                    ForEach(courses) { course in
                        CourseCard(course: course)
                    }
                }
                .padding(GDCTokens.Space.l)
            }
        }
        }
    }
}

struct CourseCard: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: GDCTokens.Space.s) {
            CoverThumbnail(
                url: course.coverImageURL,
                fallbackSymbol: "graduationcap.fill",
                tint: .accentColor,
                height: 150,
                lightboxTitle: course.name
            )
            HStack(alignment: .top, spacing: 6) {
                Text(course.name).font(.headline)
                Spacer(minLength: 4)
                BadgePill(text: L.t(accessTypeKey), color: accessTypeColor)
            }
            HStack(spacing: GDCTokens.Space.s) {
                CountdownBadge(scheduling: course.scheduling)
                if let formatLabel = course.formatLabel, !formatLabel.trimmingCharacters(in: .whitespaces).isEmpty {
                    Label(formatLabel, systemImage: "clock").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(validityText).font(.caption2).foregroundStyle(.secondary)
            CollapsibleDescription(text: course.description)

            if let accessLink = course.accessLink,
               !accessLink.trimmingCharacters(in: .whitespaces).isEmpty,
               let url = URL(string: accessLink) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label(L.t("courses.access.link"), systemImage: "link")
                }
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(course.options) { option in
                    HStack {
                        Text(option.label).font(.caption)
                        Spacer()
                        Text(option.priceDisplay).font(.caption).foregroundStyle(.secondary)
                        Button(L.t("courses.contact")) { NSWorkspace.shared.open(contactURL(for: option)) }
                            .controlSize(.small)
                    }
                }
            }
            SocialLinksRow(course.socialLinks)
        }
        .padding(GDCTokens.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardBackground()
    }

    private var accessTypeKey: String { "courses.access.\(course.accessType.rawValue)" }

    private var accessTypeColor: Color {
        switch course.accessType {
        case .free: return .green
        case .oneTime: return .accentColor
        case .subscription: return .purple
        case .liveMentoring: return .orange
        }
    }

    private var validityText: String {
        switch course.validity {
        case .lifetime: return L.t("courses.validity.lifetime")
        case .days(let d): return String(format: L.t("courses.validity.days"), d)
        }
    }

    private func contactURL(for option: CourseOption) -> URL {
        let text = String(format: L.t("courses.contact.message"), course.name, option.label, option.priceDisplay)
        return WhatsAppLink.url(text: text)
    }
}
