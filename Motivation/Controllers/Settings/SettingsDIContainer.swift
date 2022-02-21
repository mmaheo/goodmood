//
//  SettingsDIContainer.swift
//  Motivation
//
//  Created by Maxime Maheo on 18/12/2021.
//

import UIKit

final class SettingsDIContainer {
    
    struct Dependencies {
        let trackingService: TrackingServiceProtocol
    }
    
    // MARK: - Properties
    
    private let dependencies: Dependencies

    // MARK: - Lifecycle

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
    
    // MARK: - Methods
    
    func makeSettingsFlowCoordinator(navigationController: UINavigationController) -> SettingsFlowCoordinator {
        SettingsFlowCoordinator(navigationController: navigationController,
                                dependencies: self)
    }
        
    // MARK: - Private methods
    
    private func makeSettingsViewModel(actions: SettingsViewModelActions) -> SettingsViewModelProtocol {
        SettingsViewModel(actions: actions,
                          trackingService: dependencies.trackingService)
    }
    
}

// MARK: - SettingsFlowCoordinatorDependencies -

extension SettingsDIContainer: SettingsFlowCoordinatorDependencies {
    func makeSettingsViewController(actions: SettingsViewModelActions) -> SettingsViewController {
        SettingsViewController.create(with: makeSettingsViewModel(actions: actions))
    }
}