//
//  SettingsViewController.swift
//  Motivation
//
//  Created by Maxime Maheo on 18/12/2021.
//

import UIKit
import RxSwift
import PKHUD

final class SettingsViewController: UIViewController {

    // MARK: - Outlets
    
    @IBOutlet private weak var tableView: UITableView! {
        didSet {
            tableView.register(cellType: SettingsToggleCell.self)
            tableView.register(cellType: SettingsTimePickerCell.self)
            tableView.register(cellType: SettingsLinkCell.self)
            tableView.register(cellType: SettingsValueCell.self)
            tableView.register(cellType: SettingsButtonCell.self)
            tableView.register(cellType: SettingsStepperCell.self)
        }
    }
    @IBOutlet private weak var appVersionLabel: UILabel!
    
    // MARK: - Properties
        
    var viewModel: SettingsViewModelProtocol!
    
    private var composition = SettingsViewModel.Composition()
    private let disposeBag = DisposeBag()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    
    // MARK: - Lifecycle
    
    static func create(with viewModel: SettingsViewModelProtocol) -> SettingsViewController {
        guard let viewController = R.storyboard.settingsViewController().instantiateInitialViewController()
                as? SettingsViewController
        else { fatalError("Could not instantiate SettingsViewController.") }
        
        viewController.viewModel = viewModel
        
        return viewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
            
        configure()
        
        bind(to: viewModel)
        
        Task {
            await viewModel.viewDidLoad()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        impactGenerator.impactOccurred()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        viewModel.viewDidAppear()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        viewModel.viewDidDisappear()
    }
    
    // MARK: - Setup methods
    
    private func configure() {
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let appBuildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        else { return }
        
        if App.env != .appStore {
            appVersionLabel.text = "\(R.string.localizable.version_x_x(appVersion, appBuildNumber)) - \(App.env.rawValue)"
        } else {
            appVersionLabel.text = R.string.localizable.version_x_x(appVersion, appBuildNumber)
        }
        
        title = R.string.localizable.settings()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close,
                                                            target: self,
                                                            action: #selector(rightBarButtonItemDidTap))
    }
    
    // MARK: - Private methods
    
    private func bind(to viewModel: SettingsViewModelProtocol) {
        viewModel.composition
            .drive(onNext: { [weak self] in
                guard let self = self else { return }
                
                self.composition = $0
                self.tableView.reloadData()
            })
            .disposed(by: disposeBag)
    }
    
    private func restore() async {
        DispatchQueue.main.async {
            HUD.show(.progress)
        }
        
        let hasSucceed = await viewModel.restore()
        
        DispatchQueue.main.async {
            if hasSucceed {
                HUD.flash(.success, delay: Constants.animationDuration)
            } else {
                HUD.flash(.error, delay: Constants.animationDuration)
            }
        }
    }
    
    // MARK: - Actions
    
    private func linkDidTap(id: String, sourceView: UIView?) {
        guard let rowId = SettingsViewModel.RowId(rawValue: id) else { return }
        
        switch rowId {
        case .sendFeedback: viewModel.sendFeedback()
        case .writeReview: viewModel.writeReview()
        case .share: viewModel.share(sourceView: sourceView)
        case .helpTranslateTheApp: viewModel.helpTranslateApp()
        default: fatalError("Can't handle \(id)")
        }
    }
    
    @objc private func rightBarButtonItemDidTap() {
        dismiss(animated: true)
    }
    
    private func buttonDidTap(id: String) {
        guard let rowId = SettingsViewModel.RowId(rawValue: id) else { return }
        
        switch rowId {
        case .restore: Task { await restore() }
        case .showPremiumPlans: viewModel.showPremiumPlans()
        default: fatalError("Can't handle \(id)")
        }
    }
}

// MARK: - UITableViewDataSource -

extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { composition.sections.count }
    
    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int { composition.sections[section].count   }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let type = composition.sections[indexPath.section].cellForIndex(indexPath.row) else { return UITableViewCell() }
        
        switch type {
        case let .toggle(viewModel):
            let cell: SettingsToggleCell = tableView.dequeueReusableCell(for: indexPath)
            cell.viewModel = viewModel
            cell.delegate = self
            cell.selectionStyle = .none
            
            return cell
        case let .timePicker(viewModel):
            let cell: SettingsTimePickerCell = tableView.dequeueReusableCell(for: indexPath)
            cell.viewModel = viewModel
            cell.delegate = self
            cell.selectionStyle = .none
            
            return cell
        case let .link(viewModel):
            let cell: SettingsLinkCell = tableView.dequeueReusableCell(for: indexPath)
            cell.viewModel = viewModel
            
            return cell
        case let .value(viewModel):
            let cell: SettingsValueCell = tableView.dequeueReusableCell(for: indexPath)
            cell.viewModel = viewModel
            cell.selectionStyle = .none
            
            return cell
        case let .button(viewModel):
            let cell: SettingsButtonCell = tableView.dequeueReusableCell(for: indexPath)
            cell.viewModel = viewModel
            
            return cell
        case let .stepper(viewModel):
            let cell: SettingsStepperCell = tableView.dequeueReusableCell(for: indexPath)
            cell.viewModel = viewModel
            cell.delegate = self
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? { composition.sections[section].title }
}

// MARK: - UITableViewDelegate -

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let type = composition.sections[indexPath.section].cellForIndex(indexPath.row) else { return .zero }
        
        switch type {
        case let .toggle(viewModel): return SettingsToggleCell.size(for: viewModel).height
        case .timePicker: return SettingsTimePickerCell.size.height
        case let .link(viewModel): return SettingsLinkCell.size(for: viewModel).height
        case .value: return SettingsValueCell.size.height
        case let .button(viewModel): return SettingsButtonCell.size(for: viewModel).height
        case let .stepper(viewModel): return SettingsStepperCell.size(for: viewModel).height
        }
    }
    
    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        guard let type = composition.sections[indexPath.section].cellForIndex(indexPath.row) else { return }
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch type {
        case let .link(viewModel): linkDidTap(id: viewModel.id,
                                              sourceView: tableView.cellForRow(at: indexPath))
        case let .button(viewModel): buttonDidTap(id: viewModel.id)
        default: break
        }
    }
}

// MARK: - SettingsToggleCellDelegate -

extension SettingsViewController: SettingsToggleCellDelegate {
    func settingsToggleCell(_ sender: SettingsToggleCell,
                            switchValueDidChange isOn: Bool,
                            id: String) {
        guard let rowId = SettingsViewModel.RowId(rawValue: id) else { return }
        
        switch rowId {
        case .hasNotificationEnabled: viewModel.toggleHasNotificationEnabled()
        case .debugPremium: Task { await viewModel.updateDebug(isPremium: isOn) }
        default: fatalError("Can't handle \(id)")
        }
    }
}

// MARK: - SettingsTimePickerCellDelegate -

extension SettingsViewController: SettingsTimePickerCellDelegate {
    func settingsTimePickerCell(_ sender: SettingsTimePickerCell,
                                timePickerValueDidChange date: Date,
                                id: String) {
        guard let rowId = SettingsViewModel.RowId(rawValue: id) else { return }
        
        switch rowId {
        case .startAt: viewModel.update(startAt: date)
        case .endAt: viewModel.update(endAt: date)
        default: fatalError("Can't handle \(id)")
        }
    }
}

// MARK: - SettingsStepperCellDelegate -

extension SettingsViewController: SettingsStepperCellDelegate {
    func settingsStepperCell(_ sender: SettingsStepperCell,
                             stepperValueDidChange value: Double,
                             id: String) {
        guard let rowId = SettingsViewModel.RowId(rawValue: id) else { return }
        
        switch rowId {
        case .nbNotifPerDay:
            viewModel.update(nbNotifPerDay: value)
            impactGenerator.impactOccurred()
        default: fatalError("Can't handle \(id)")
        }
    }
}
