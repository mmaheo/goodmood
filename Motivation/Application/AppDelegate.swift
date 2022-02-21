//
//  AppDelegate.swift
//  Motivation
//
//  Created by Maxime Maheo on 19/02/2022.
//

import UIKit
import Bugsnag

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - Properties
    
    var window: UIWindow?
    
    private let appDIContainer = AppDIContainer()
    private var appFlowCoordinator: AppFlowCoordinator?
    
    // MARK: - Methods
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if App.env == .appStore {
            Bugsnag.start()
            Bugsnag.setUser(UserIdentifierManager.shared.userId,
                            withEmail: nil,
                            andName: nil)
        }
        
        window = UIWindow(frame: UIScreen.main.bounds)
        
        let navigationController = UINavigationController()
        
        window?.rootViewController = navigationController
        
        appFlowCoordinator = AppFlowCoordinator(navigationController: navigationController,
                                                appDIContainer: appDIContainer)
        appFlowCoordinator?.start()
        
        window?.makeKeyAndVisible()
                
        return true
    }
}
