//
//  HistoryViewController.swift
//  Clip
//
//  Created by Riley Testut on 6/10/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import MobileCoreServices
import Combine
import CoreLocation
import Contacts

import ClipKit
import Roxas

class HistoryViewController: UITableViewController
{
    private var dataSource: RSTFetchedResultsTableViewPrefetchingDataSource<PasteboardItem, UIImage>!
    
    private let _undoManager = UndoManager()
    
    private var prototypeCell: ClippingTableViewCell!
    private var navigationBarMaskView: UIView!
    private var navigationBarGradientView: GradientView!
    
    private var didAddInitialLayoutConstraints = false
    private var cachedHeights = [NSManagedObjectID: CGFloat]()
    
    private weak var selectedItem: PasteboardItem?
    private var updateTimer: Timer?
    private var fetchLimitSettingObservation: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()
    
    // 在HistoryViewController类中添加以下属性
    private var isMultiSelectMode: Bool = false
    private var selectedIndexPaths: Set<IndexPath> = []
    private var multiSelectBarButtonItem: UIBarButtonItem!
    private var cancelBarButtonItem: UIBarButtonItem!
    private let multiSelectToolbar = UIToolbar()
    
    // 在HistoryViewController类中添加
    private var selectedItems: [PasteboardItem] = []
    
    // 新增方法：切换项目选择状态
    private func toggleSelection(for indexPath: IndexPath) {
        let item = dataSource.item(at: indexPath)
        
        // 更新选中项数组
        if let existingIndex = selectedItems.firstIndex(where: { $0.objectID == item.objectID }) {
            selectedItems.remove(at: existingIndex)
        } else {
            selectedItems.append(item)
        }
        
        // 更新单元格选中状态
        if let cell = tableView.cellForRow(at: indexPath) as? ClippingTableViewCell {
            let isSelected = selectedItems.contains { $0.objectID == item.objectID }
            cell.updateSelectionState(isSelected: isSelected)
        }
        
        // 更新导航栏按钮状态
        updateNavigationBar()
    }
    
    // 更新导航栏，显示拼贴按钮
    private func updateNavigationBar() {
        if isMultiSelectMode {
            // 多选模式下始终显示"拼贴"按钮
            let collageButton = UIBarButtonItem(
                title: NSLocalizedString("Tile", comment: ""),
                style: .done,
                target: self,
                action: #selector(createCollage)
            )
            collageButton.isEnabled = !selectedItems.isEmpty // 没有选中项时禁用
            navigationItem.rightBarButtonItem = collageButton
        } else {
            // 非多选模式恢复原来的导航栏按钮
            setupNavigationBar()
        }
    }
    
    // 跳转到拼贴编辑器
    @objc private func createCollage() {
        guard !selectedItems.isEmpty else { return }
        
        let editor = CollageEditorViewController(items: selectedItems)
        
        // 设置关闭回调
        editor.onDismiss = { [weak self] shouldKeepSelection in
            guard let self = self else { return }
            
            if !shouldKeepSelection {
                // 只有完成分享后才清除选中状态
                self.selectedItems.removeAll()
                self.tableView.reloadData()
                self.updateNavigationBar()
            }
            // 取消时不做任何操作，保留选中状态
        }
        
        let navigationController = UINavigationController(rootViewController: editor)
        // 关键：检查当前是否有正在显示的弹窗，有则先关闭
        if let presentedVC = self.presentedViewController {
            presentedVC.dismiss(animated: true) {
                self.present(navigationController, animated: true)
            }
        } else {
            self.present(navigationController, animated: true)
        }
        
    }
    
    
    private lazy var dateComponentsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = [.second, .minute, .hour, .day]
        return formatter
    }()
    
    override var undoManager: UndoManager? {
        return _undoManager
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // 设置导航栏标题为“剪下灵感，留下痕迹”
        self.title = NSLocalizedString("Clip", comment: "主界面列表的导航栏标题")
        // 调整标题字体大小（设置为16号字体，比默认略小）
        navigationController?.navigationBar.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium), // 字体大小16，中等字重
            .foregroundColor: UIColor.label // 保持默认文本颜色（适应深色/浅色模式）
        ]
        
        
        self.subscribe()
        
        self.extendedLayoutIncludesOpaqueBars = true
        
        self.tableView.backgroundView = self.makeGradientView()
        
        self.updateDataSource()
        
        self.tableView.contentInset.top = 8
        self.tableView.estimatedRowHeight = 0
        
        self.prototypeCell = ClippingTableViewCell.instantiate(with: ClippingTableViewCell.nib!)
        self.tableView.register(ClippingTableViewCell.nib, forCellReuseIdentifier: RSTCellContentGenericCellIdentifier)
        
        DatabaseManager.shared.persistentContainer.viewContext.undoManager = self.undoManager
        
        NotificationCenter.default.addObserver(self, selector: #selector(HistoryViewController.didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(HistoryViewController.willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(HistoryViewController.settingsDidChange(_:)), name: SettingsViewController.settingsDidChangeNotification, object: nil)
        
        self.fetchLimitSettingObservation = UserDefaults.shared.observe(\.historyLimit) { [weak self] (defaults, change) in
            self?.updateDataSource()
        }
        
        self.navigationBarGradientView = self.makeGradientView()
        self.navigationBarGradientView.translatesAutoresizingMaskIntoConstraints = false
        
        self.navigationBarMaskView = UIView()
        self.navigationBarMaskView.clipsToBounds = true
        self.navigationBarMaskView.translatesAutoresizingMaskIntoConstraints = false
        self.navigationBarMaskView.addSubview(self.navigationBarGradientView)
        
        if let navigationBar = self.navigationController?.navigationBar
        {
            if #available(iOS 13.0, *)
            {
                let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white]
                
                let standardAppearance = navigationBar.standardAppearance
                standardAppearance.configureWithOpaqueBackground()
                standardAppearance.backgroundColor = .clipLightPink
                standardAppearance.titleTextAttributes = attributes
                standardAppearance.largeTitleTextAttributes = attributes
                standardAppearance.shadowImage = nil
                
                let scrollEdgeAppearance = navigationBar.scrollEdgeAppearance
                scrollEdgeAppearance?.configureWithTransparentBackground()
                scrollEdgeAppearance?.titleTextAttributes = attributes
                scrollEdgeAppearance?.largeTitleTextAttributes = attributes
            }
            else
            {
                navigationBar.shadowImage = UIImage()
                navigationBar.setBackgroundImage(nil, for: .default)
                navigationBar.insertSubview(self.navigationBarMaskView, at: 1)
            }
        }
        
        if let tabBar = self.navigationController?.tabBarController?.tabBar
        {
            let appearance = tabBar.standardAppearance
            tabBar.scrollEdgeAppearance = appearance
        }
        
        self.navigationController?.tabBarItem.image = UIImage(systemName: "list.bullet")
        
        // 添加本地化标题
        self.navigationController?.tabBarItem.title = NSLocalizedString("List", comment: "标签栏中“列表”功能的名称")
        
        // 添加Settings入口按钮（若不存在则新增，若已存在则修改标题）
        let settingsButton = UIBarButtonItem(
            title: NSLocalizedString("Settings", comment: "导航栏中打开设置的按钮标题"),
            style: .plain,
            target: self,
            action: #selector(openSettings)
        )
        navigationItem.rightBarButtonItem = settingsButton
        
        // 启用表格多选
        self.tableView.allowsMultipleSelection = true
        // 添加长按手势触发多选
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        self.tableView.addGestureRecognizer(longPress)
        
        // 添加拼贴分享按钮（仅在多选时显示）
        let collageButton = UIBarButtonItem(title: "拼贴", style: .plain, target: self, action: #selector(showCollageEditor))
        self.navigationItem.rightBarButtonItem = collageButton
        collageButton.isEnabled = false
        
        // 如需支持双击，添加双击手势（可选）
//        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
//        doubleTap.numberOfTapsRequired = 2
//        tableView.addGestureRecognizer(doubleTap)
        // 允许单击和双击并存
//        tableView.gestureRecognizers?.first(where: { $0 is UITapGestureRecognizer })?.require(toFail: doubleTap)
        
        
        setupNavigationBar()
        setupLongPressGesture()
        
        self.startUpdating()
    }

    // 双击手势处理（可选，与上面的handleCellTap配合使用）
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: tableView)
        if let indexPath = tableView.indexPathForRow(at: point) {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            handleCellTap(at: indexPath) // 复用点击处理逻辑
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, !isMultiSelectMode else { return }
        
        let point = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }
        
        // 进入多选模式并选中当前项
        enterMultiSelectMode()
        toggleSelection(at: indexPath)
    }
    // 进入多选模式
    private func enterMultiSelectMode() {
        isMultiSelectMode = true
        selectedItems.removeAll()
        selectedIndexPaths.removeAll()
        
        // 更新导航栏
        navigationItem.leftBarButtonItem = cancelBarButtonItem
        updateNavigationBar() // 复用导航栏更新逻辑
        
        // 添加工具栏到视图
        view.addSubview(multiSelectToolbar)
        
        // 2. 正确添加约束（关联到safeArea，确保宽高正常）
        NSLayoutConstraint.activate([
            // 宽度：与父视图等宽（解决width=0问题）
            multiSelectToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            multiSelectToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // 高度：固定44（符合系统工具栏高度）
            multiSelectToolbar.heightAnchor.constraint(equalToConstant: 44),
            // 位置：底部贴紧safeArea（避免被HomeIndicator遮挡）
            multiSelectToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // 刷新表格显示选择框
        tableView.reloadData()
    }
    // 完成多选操作
    @objc private func finishMultiSelect() {
        isMultiSelectMode = false
        selectedItems.removeAll()
        selectedIndexPaths.removeAll()
        
        // 退出多选模式时移除右侧按钮
        navigationItem.rightBarButtonItem = nil
        // 恢复左侧按钮
        setupNavigationBar()
        
        // 移除底部工具栏
        multiSelectToolbar.removeFromSuperview()
        
        // 刷新表格
        tableView.reloadData()
    }
    
    // 切换选择状态
    private func toggleSelection(at indexPath: IndexPath) {
        
        let item = dataSource.item(at: indexPath)
        
        if let index = selectedItems.firstIndex(where: { $0 == item }) {
            selectedItems.remove(at: index)
        } else {
            selectedItems.append(item)
        }
        
        if let cell = tableView.cellForRow(at: indexPath) as? ClippingTableViewCell {
            let isSelected = selectedItems.contains(item)
            cell.updateSelectionState(isSelected: isSelected)
        }
        
        // 确保每次选择变化都更新导航栏按钮状态
        updateNavigationBar()
        
    }
    // 更新多选按钮状态
    private func updateMultiSelectButtons() {
        let count = selectedIndexPaths.count
        multiSelectBarButtonItem.title = count > 0 ? "\(count)项" : NSLocalizedString("完成", comment: "")
    }
    // 设置底部工具栏
    private func setupMultiSelectToolbar() {
        // 1. 禁用自动约束（关键：避免系统生成冲突约束）
        multiSelectToolbar.translatesAutoresizingMaskIntoConstraints = false
        
        // 2. 设置工具栏基础样式
        multiSelectToolbar.barTintColor = .systemBackground
        multiSelectToolbar.tintColor = .clipPink // 匹配主题色
        multiSelectToolbar.layer.borderWidth = 0 // 移除多余边框
        
        // 3. 添加"拼贴"按钮（使用UIBarButtonItem系统样式，避免文字约束冲突）
        let collageButton = UIBarButtonItem(
            title: NSLocalizedString("拼贴", comment: ""),
            style: .done,
            target: self,
            action: #selector(createCollage)
        )
        // 初始禁用（无选中项时）
        collageButton.isEnabled = !selectedItems.isEmpty
        
        // 4. 使用弹性空间让按钮居中
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        multiSelectToolbar.items = [flexSpace, collageButton, flexSpace]
    }
    
    // 退出多选模式
    @objc private func cancelMultiSelect() {
        isMultiSelectMode = false
        selectedItems.removeAll()
        selectedIndexPaths.removeAll()
        
        // 移除工具栏（关键：避免多次进入多选模式导致重复添加）
        multiSelectToolbar.removeFromSuperview()
        
        // 恢复导航栏
        navigationItem.leftBarButtonItem = nil
        setupNavigationBar()
        
        // 刷新表格
        tableView.reloadData()
    }
    
    
    
    private func updateCollageButtonState() {
        let selectedCount = tableView.indexPathsForSelectedRows?.count ?? 0
        let isEnabled = selectedCount >= 1
        
        navigationItem.rightBarButtonItem?.isEnabled = isEnabled
        navigationItem.rightBarButtonItem?.tintColor = isEnabled ? .white : .gray
    }
    
    @objc private func showCollageEditor() {
        guard let selectedIndexPaths = tableView.indexPathsForSelectedRows else { return }
        let selectedItems = selectedIndexPaths.compactMap { dataSource.fetchedResultsController.object(at: $0) }
        let editorVC = CollageEditorViewController(items: selectedItems)
        self.present(UINavigationController(rootViewController: editorVC), animated: true)
    }
    
    private func setupNavigationBar() {
        // 默认导航按钮（原设置按钮）
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(openSettings)
        )
        
        // 多选模式导航按钮
        cancelBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("取消", comment: ""),
            style: .plain,
            target: self,
            action: #selector(cancelMultiSelect)
        )
        
        multiSelectBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("完成", comment: ""),
            style: .done,
            target: self,
            action: #selector(finishMultiSelect)
        )
        
        navigationItem.rightBarButtonItem = settingsButton
    }
    // 添加长按手势识别器
    private func setupLongPressGesture() {
        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        tableView.addGestureRecognizer(longPress)
    }
    
    // 在当前视图控制器中添加以下方法
    @objc private func openSettings() {
        // 触发到设置页面的segue，确保storyboard中存在identifier为"showSettings"的segue
        performSegue(withIdentifier: "showSettings", sender: self)
        
        let settingsVC = SettingsViewController(style: .grouped)
        let navigationController = ForwardingNavigationController(rootViewController: settingsVC)
        present(navigationController, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        self.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        self.resignFirstResponder()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.cachedHeights.removeAll()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        if #available(iOS 13.0, *) {}
        else
        {
            if let navigationBar = self.navigationController?.navigationBar, !self.didAddInitialLayoutConstraints
            {
                self.didAddInitialLayoutConstraints = true
                
                NSLayoutConstraint.activate([self.navigationBarGradientView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                                             self.navigationBarGradientView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                                             self.navigationBarGradientView.topAnchor.constraint(equalTo: self.view.topAnchor),
                                             self.navigationBarGradientView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)])
                
                NSLayoutConstraint.activate([self.navigationBarMaskView.leadingAnchor.constraint(equalTo: navigationBar.leadingAnchor),
                                             self.navigationBarMaskView.trailingAnchor.constraint(equalTo: navigationBar.trailingAnchor),
                                             self.navigationBarMaskView.topAnchor.constraint(equalTo: self.view.topAnchor),
                                             self.navigationBarMaskView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor)])
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard segue.identifier == "showSettings" else { return }
        guard let sender = sender as? UIBarButtonItem else { return }
        
        let navigationController = segue.destination as! UINavigationController
        
        let settingsViewController = navigationController.viewControllers[0] as! SettingsViewController
        settingsViewController.view.layoutIfNeeded()
        
        navigationController.preferredContentSize = CGSize(width: 375, height: settingsViewController.tableView.contentSize.height)
        
        navigationController.popoverPresentationController?.delegate = self
        navigationController.popoverPresentationController?.barButtonItem = sender
    }
}

extension HistoryViewController
{
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool
    {
        let supportedActions = [#selector(UIResponderStandardEditActions.copy(_:)), #selector(UIResponderStandardEditActions.delete(_:)), #selector(HistoryViewController._share(_:))]
        
        let isSupported = supportedActions.contains(action)
        return isSupported
    }
    
    @objc override func copy(_ sender: Any?)
    {
        guard let item = self.selectedItem else { return }
        
        UIPasteboard.general.copy(item)
    }
    
    @objc override func delete(_ sender: Any?)
    {
        guard let item = self.selectedItem else { return }
        
        // Use the main view context so we can undo this operation easily.
        // Saving a context can mess with its undo history, so we only save main context when we enter background.
        item.isMarkedForDeletion = true
    }
    
    @objc func _share(_ sender: Any?)
    {
        guard let item = self.selectedItem, let indexPath = self.dataSource.fetchedResultsController.indexPath(forObject: item) else { return }
        
        let cell = self.tableView.cellForRow(at: indexPath)
        
        let activityViewController = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceItem = cell
        self.present(activityViewController, animated: true, completion: nil)
    }
}

private extension HistoryViewController
{
    func subscribe()
    {
        //TODO: Uncomment once we can tell user to enable location for background execution.
        //ApplicationMonitor.shared.locationManager.$status
        //    .receive(on: RunLoop.main)
        //    .compactMap { $0?.error }
        //    .sink { self.present($0) }
        //    .store(in: &self.cancellables)
    }
    
    func makeDataSource() -> RSTFetchedResultsTableViewPrefetchingDataSource<PasteboardItem, UIImage>
    {
        let fetchRequest = PasteboardItem.historyFetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.relationshipKeyPathsForPrefetching = [#keyPath(PasteboardItem.preferredRepresentation)]
        
        let dataSource = RSTFetchedResultsTableViewPrefetchingDataSource<PasteboardItem, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.persistentContainer.viewContext)
        dataSource.cellConfigurationHandler = { [weak self] (cell, item, indexPath) in
            let cell = cell as! ClippingTableViewCell
            cell.contentLabel.isHidden = false
            cell.contentImageView.isHidden = true
            
            self?.updateDate(for: cell, item: item)
            
            if let representation = item.preferredRepresentation
            {
                cell.titleLabel.text = representation.type.localizedName
                
                switch representation.type
                {
                case .text: cell.contentLabel.text = representation.stringValue
                case .attributedText: cell.contentLabel.text = representation.attributedStringValue?.string
                case .url: cell.contentLabel.text = representation.urlValue?.absoluteString
                case .image:
                    cell.contentLabel.isHidden = true
                    cell.contentImageView.isHidden = false
                    cell.contentImageView.isIndicatingActivity = true
                }
            }
            else
            {
                cell.titleLabel.text = NSLocalizedString("Unknown", comment: "")
                cell.contentLabel.isHidden = true
            }
            
            if UserDefaults.shared.showLocationIcon
            {
                cell.locationButton.isHidden = (item.location == nil)
                cell.locationButton.addTarget(self, action: #selector(HistoryViewController.showLocation(_:)), for: .primaryActionTriggered)
            }
            else
            {
                cell.locationButton.isHidden = true
            }
            
            if indexPath.row < UserDefaults.shared.historyLimit.rawValue
            {
                cell.bottomConstraint.isActive = true
            }
            else
            {
                // Make it not active so we can collapse the cell to a height of 0 without auto layout errors.
                cell.bottomConstraint.isActive = false
            }
            // 根据多选模式更新选择指示器显示
            let isMultiSelectMode = self?.isMultiSelectMode ?? false
            cell.selectionIndicator.isHidden = !isMultiSelectMode
            
            // 更新选择状态
            let isSelected = self?.selectedIndexPaths.contains(indexPath) ?? false
            cell.updateSelectionState(isSelected: isSelected)
            
        }
        
        dataSource.prefetchHandler = { (item, indexPath, completionHandler) in
            guard let representation = item.preferredRepresentation, representation.type == .image else { return nil }
            
            return RSTBlockOperation() { (operation) in
                guard let image = representation.imageValue?.resizing(toFill: CGSize(width: 500, height: 500)) else { return completionHandler(nil, nil) }
                completionHandler(image, nil)
            }
        }
        
        dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            DispatchQueue.main.async {
                let cell = cell as! ClippingTableViewCell
                
                if let image = image
                {
                    cell.contentImageView.image = image
                }
                else
                {
                    cell.contentImageView.image = nil
                }
                
                cell.contentImageView.isIndicatingActivity = false
            }
        }
        
        let placeholderView = RSTPlaceholderView()
        placeholderView.textLabel.text = NSLocalizedString("No Clippings", comment: "")
        placeholderView.textLabel.textColor = .white
        placeholderView.detailTextLabel.text = NSLocalizedString("Items that you've copied to the clipboard will appear here.", comment: "")
        placeholderView.detailTextLabel.textColor = .white
        
        let vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: UIBlurEffect(style: .dark)))
        vibrancyView.contentView.addSubview(placeholderView, pinningEdgesWith: .zero)
        
        let gradientView = self.makeGradientView()
        gradientView.addSubview(vibrancyView, pinningEdgesWith: .zero)
        dataSource.placeholderView = gradientView
        
        return dataSource
    }
    
    func makeGradientView() -> GradientView
    {
        let gradientView = GradientView()
        gradientView.colors = [.clipLightPink, .clipPink]
        return gradientView
    }
    
    func updateDataSource()
    {
        self.stopUpdating()
        
        self.dataSource = self.makeDataSource()
        self.tableView.dataSource = self.dataSource
        self.tableView.prefetchDataSource = self.dataSource
        self.tableView.reloadData()
        
        self.startUpdating()
    }
    
    func updateDate(for cell: ClippingTableViewCell, item: PasteboardItem)
    {
        if Date().timeIntervalSince(item.date) < 2
        {
            cell.dateLabel.text = NSLocalizedString("now", comment: "")
        }
        else
        {
            cell.dateLabel.text = self.dateComponentsFormatter.string(from: item.date, to: Date())
        }
    }
    
    func showMenu(at indexPath: IndexPath)
    {
        guard let cell = self.tableView.cellForRow(at: indexPath) as? ClippingTableViewCell else { return }
        
        let item = self.dataSource.item(at: indexPath)
        self.selectedItem = item
        
        let targetRect = cell.clippingView.frame
        
        self.becomeFirstResponder()
        
        UIMenuController.shared.setTargetRect(targetRect, in: cell)
        UIMenuController.shared.setMenuVisible(true, animated: true)
    }
    
    @objc func showLocation(_ sender: UIButton)
    {
        let point = self.view.convert(sender.center, from: sender.superview!)
        guard let indexPath = self.tableView.indexPathForRow(at: point) else { return }
        
        let item = self.dataSource.item(at: indexPath)
        guard let location = item.location else { return }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            DispatchQueue.main.async {
                let title: String
                let message: String?
                
                if let placemarks, let placemark = placemarks.first,
                   let postalAddress = placemark.postalAddress?.mutableCopy() as? CNMutablePostalAddress
                {
                    // The location isn't precise, so don't pretend that it is by showing street address.
                    postalAddress.street = ""
                    postalAddress.subLocality = ""
                    
                    let formatter = CNPostalAddressFormatter()
                    
                    if let sublocality = placemark.subLocality
                    {
                        title = sublocality + "\n" + formatter.string(from: postalAddress)
                    }
                    else
                    {
                        title = formatter.string(from: postalAddress)
                    }
                    
                    message = nil
                }
                else if let error
                {
                    title = NSLocalizedString("Unable to Look Up Location", comment: "")
                    message = error.localizedDescription + "\n\n" + "\(location.coordinate.latitude), \(location.coordinate.longitude)"
                }
                else
                {
                    title = "\(location.coordinate.latitude), \(location.coordinate.longitude)"
                    message = nil
                }
                
                let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alertController.addAction(.ok)
                self.present(alertController, animated: true)
            }
        }
    }
    
    func startUpdating()
    {
        self.stopUpdating()
        
        self.updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] (timer) in
            guard let self = self else { return }
            
            for indexPath in self.tableView.indexPathsForVisibleRows ?? []
            {
                guard let cell = self.tableView.cellForRow(at: indexPath) as? ClippingTableViewCell else { continue }
                
                let item = self.dataSource.item(at: indexPath)
                self.updateDate(for: cell, item: item)
            }
        }
    }
    
    func stopUpdating()
    {
        self.updateTimer?.invalidate()
        self.updateTimer = nil
    }
}

private extension HistoryViewController
{
    func present(_ error: Error)
    {
        let nsError = error as NSError
        
        let alertController = UIAlertController(title: nsError.localizedFailureReason ?? nsError.localizedDescription,
                                                message: nsError.localizedRecoverySuggestion, preferredStyle: .alert)
        
        if let recoverableError = error as? RecoverableError, !recoverableError.recoveryOptions.isEmpty
        {
            alertController.addAction(.cancel)
            
            for (index, title) in zip(0..., recoverableError.recoveryOptions)
            {
                let action = UIAlertAction(title: title, style: .default) { (action) in
                    recoverableError.attemptRecovery(optionIndex: index) { (success) in
                        print("Recovered from error with success:", success)
                    }
                }
                alertController.addAction(action)
            }
        }
        else
        {
            alertController.addAction(.ok)
        }
        
        self.present(alertController, animated: true, completion: nil)
    }
}

private extension HistoryViewController
{
    @objc func didEnterBackground(_ notification: Notification)
    {
        // Save any pending changes to disk.
        if DatabaseManager.shared.persistentContainer.viewContext.hasChanges
        {
            do
            {
                try DatabaseManager.shared.persistentContainer.viewContext.save()
            }
            catch
            {
                print("Failed to save view context.", error)
            }
        }
        
        self.undoManager?.removeAllActions()
        
        self.stopUpdating()
    }
    
    @objc func willEnterForeground(_ notification: Notification)
    {
        self.startUpdating()
    }
    
    @objc func settingsDidChange(_ notification: Notification)
    {
        self.tableView.reloadData()
    }
    
    @IBAction func unwindToHistoryViewController(_ segue: UIStoryboardSegue)
    {
    }
}

extension HistoryViewController
{
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        // It's far *far* easier to simply set row height to 0 for cells beyond history limit
        // than to actually limit fetched results to the correct number live (with insertions and deletions).
        guard indexPath.row < UserDefaults.shared.historyLimit.rawValue else { return 0.0 }
        
        let item = self.dataSource.item(at: indexPath)
        
        if let height = self.cachedHeights[item.objectID]
        {
            return height
        }
        
        let portraitScreenHeight = UIScreen.main.coordinateSpace.convert(UIScreen.main.bounds, to: UIScreen.main.fixedCoordinateSpace).height
        let maximumHeight: CGFloat
        
        if item.preferredRepresentation?.type == .image
        {
            maximumHeight = portraitScreenHeight / 2
        }
        else
        {
            maximumHeight = portraitScreenHeight / 3
        }
        
        let widthConstraint = self.prototypeCell.contentView.widthAnchor.constraint(equalToConstant: tableView.bounds.width)
        let heightConstraint = self.prototypeCell.contentView.heightAnchor.constraint(lessThanOrEqualToConstant: maximumHeight)
        NSLayoutConstraint.activate([widthConstraint, heightConstraint])
        defer { NSLayoutConstraint.deactivate([widthConstraint, heightConstraint]) }
        
        self.dataSource.cellConfigurationHandler(self.prototypeCell, item, indexPath)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        self.cachedHeights[item.objectID] = size.height
        return size.height
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // 双击会触发两次选中事件，这里先取消选中状态（避免视觉残留）
        tableView.deselectRow(at: indexPath, animated: true)
        
        if isMultiSelectMode {
            toggleSelection(for: indexPath)
        } else {
            // 普通模式：处理单击/双击逻辑（双击可通过手势识别单独处理）
            self.showMenu(at: indexPath)
//            handleCellTap(at: indexPath)
        }
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isMultiSelectMode {
            toggleSelection(for: indexPath)
        } else {
            super.tableView(tableView, didDeselectRowAt: indexPath)
        }
    }
    // 单独处理普通模式下的单元格点击（可选：添加双击支持）
    private func handleCellTap(at indexPath: IndexPath) {
        let selectedItem = dataSource.item(at: indexPath)
        
        // 用项目中已存在的控制器替换（例如用CollageEditorViewController预览单个内容）
        let previewVC = CollageEditorViewController(items: [selectedItem]) // 传入单个item
        present(UINavigationController(rootViewController: previewVC), animated: true)
    }
    
}

extension HistoryViewController: UIPopoverPresentationControllerDelegate
{
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle
    {
        return .none
    }
}
