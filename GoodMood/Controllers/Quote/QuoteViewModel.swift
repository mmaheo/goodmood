//
//  QuoteViewModel.swift
//  Motivation
//
//  Created by Maxime Maheo on 20/02/2022.
//

import RxSwift
import RxCocoa
import Foundation

struct QuoteViewModelActions {
    let presentSettings: () -> Void
    let presentCategory: () -> Void
    let presentTemplateViewController: () -> Void
    let presentPreReviewPopup: (@escaping () -> Void, @escaping () -> Void) -> Void
}

protocol QuoteViewModelProtocol: AnyObject {
    
    // MARK: - Properties
    
    var composition: Driver<QuoteViewModel.Composition> { get }
    var selectedTemplate: BehaviorRelay<String?> { get }
    
    // MARK: - Methods
    
    func viewDidAppear()
    func refreshQuotesIfNeeded()
    func refreshSelectedCategory()
    func showNextQuote()
    func presentSettings()
    func presentCategory()
    func presentTemplateViewController()
    func refreshSelectedTemplate()
}

final class QuoteViewModel: QuoteViewModelProtocol {
    
    // MARK: - Properties
    
    let selectedTemplate: BehaviorRelay<String?>
    
    lazy private(set) var composition: Driver<Composition> = compositionSubject.asDriver(onErrorDriveWith: .never())
    
    private let compositionSubject = ReplaySubject<Composition>.create(bufferSize: 1)
    
    private let actions: QuoteViewModelActions
    private let databaseService: DatabaseServiceProtocol
    private let trackingService: TrackingServiceProtocol
    private let preferenceService: PreferenceServiceProtocol
    private var selectedCategory: RMQuote.RMCategory
    private var newSelectedCategory: RMQuote.RMCategory?
    private var rateAppPopupShownInSession = false
    
    // MARK: - Lifecycle
    
    init(actions: QuoteViewModelActions,
         databaseService: DatabaseServiceProtocol,
         trackingService: TrackingServiceProtocol,
         preferenceService: PreferenceServiceProtocol) {
        self.actions = actions
        self.databaseService = databaseService
        self.trackingService = trackingService
        self.preferenceService = preferenceService
        self.selectedCategory = preferenceService.getSelectedCategory()
        self.selectedTemplate = .init(value: preferenceService.selectedTemplate())
        
        trackingService.set(userProperty: .nbNotifPerDay, value: NSNumber(value: preferenceService.getNbTimesNotif()))
        
        configureComposition()
    }
    
    // MARK: - Methods
    
    func viewDidAppear() {
        trackingService.track(event: .showQuoteScreen, eventProperties: nil)
        trackingService.increment(userProperty: .nbQuotesShown, value: 1)
        
        rateAppIfNeeded()
    }
    
    func refreshQuotesIfNeeded() {
        guard shouldRefreshQuotes() else { return }
        
        selectedCategory = preferenceService.getSelectedCategory()
        
        guard let quotes = try? databaseService.getQuotes(language: RMQuote.RMLanguage.user,
                                                          category: selectedCategory)
        else { return }
        
        configureComposition(quotes: quotes)
    }
    
    func refreshSelectedCategory() {
        newSelectedCategory = preferenceService.getSelectedCategory()
        
        refreshQuotesIfNeeded()
    }
    
    func refreshSelectedTemplate() {
        selectedTemplate.accept(preferenceService.selectedTemplate())
    }
    
    func showNextQuote() {
        trackingService.track(event: .showNextQuote, eventProperties: [.category: selectedCategory.rawValue])
        trackingService.increment(userProperty: .nbQuotesShown, value: 1)
    }
    
    func presentSettings() {
        actions.presentSettings()
    }
    
    func presentCategory() {
        actions.presentCategory()
    }
    
    func presentTemplateViewController() {
        actions.presentTemplateViewController()
    }
    
    // MARK: - Methods
    
    private func shouldRefreshQuotes() -> Bool {
        selectedCategory != newSelectedCategory
    }
    
    private func rateAppIfNeeded() {
        let nbAppLaunch = preferenceService.getNbAppLaunch()
        let hasRateApp = preferenceService.hasRateApp()

        if !hasRateApp,
           !rateAppPopupShownInSession,
           shouldShowPreReviewPopup(nbAppLaunch: nbAppLaunch) {
            trackingService.increment(userProperty: .nbTimesShowLikeApp, value: 1)
            trackingService.track(event: .showRatePopup, eventProperties: nil)

            rateAppPopupShownInSession = true

            actions.presentPreReviewPopup(declineReview, acceptReview)
        }
    }
    
    private func shouldShowPreReviewPopup(nbAppLaunch: Int) -> Bool {
        nbAppLaunch == 2 || nbAppLaunch.isMultiple(of: 7)
    }
    
    private func acceptReview() {
        trackingService.track(event: .rateApp, eventProperties: nil)
        preferenceService.appWasRated()
    }
    
    private func declineReview() {
        trackingService.track(event: .declineRateApp, eventProperties: nil)
    }
}

// MARK: - Composition -

extension QuoteViewModel {
    typealias Section = CompositionSection<SectionType, Cell>
    
    struct Composition {
        var sections = [Section]()
    }
    
    enum SectionType {
        case quotes
    }
    
    enum Cell {
        case quote(_ for: QuoteCellViewModel)
    }
    
    // MARK: - Private methods
    
    private func configureComposition(quotes: [Quote] = []) {
        var sections = [Section]()
        
        if let quotesSection = configureQuotesSection(quotes: quotes) {
            sections.append(quotesSection)
        }
        
        compositionSubject.onNext(Composition(sections: sections))
    }
    
    private func configureQuotesSection(quotes: [Quote]) -> Section? {
        guard !quotes.isEmpty else { return nil }
        
        let cells: [Cell] = quotes.map { .quote(QuoteCellViewModel(content: $0.content)) }
        
        return .section(.quotes,
                        title: nil,
                        cells: cells)
    }
}
