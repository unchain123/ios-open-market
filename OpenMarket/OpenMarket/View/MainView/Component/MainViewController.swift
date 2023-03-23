//
//  OpenMarket - ViewController.swift
//  Created by yagom.
//  Copyright Â© yagom. All rights reserved.
//

import UIKit
import Combine

 enum Section {
    case main
}

final class MainViewController: UIViewController {

    private typealias DiffableDataSource = UICollectionViewDiffableDataSource<Section, PageInformation>
    
    // MARK: Properties
    
    private let viewModel = MainViewModel()
    private var cancellable = Set<AnyCancellable>()

    private lazy var loadingView: UIActivityIndicatorView = {
        let loadingView = UIActivityIndicatorView()
        loadingView.center = self.view.center
        loadingView.startAnimating()
        loadingView.style = UIActivityIndicatorView.Style.large
        loadingView.isHidden = false
        return loadingView
    }()
    
    private var dataSource: DiffableDataSource?
    private var snapshot = NSDiffableDataSourceSnapshot<Section, PageInformation>()
    private var productPageNumber = 1
    
    private lazy var segmentedControl: UISegmentedControl = {
        let segment = UISegmentedControl(items: [CollectionViewNamespace.list.name, CollectionViewNamespace.grid.name])
        segment.selectedSegmentIndex = Metric.firstSegment
        segment.addTarget(self, action: #selector(handleSegmentChange), for: .valueChanged)
        segment.translatesAutoresizingMaskIntoConstraints = false
        segment.selectedSegmentTintColor = .systemBlue
        segment.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.white], for: UIControl.State.selected)
        segment.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.link], for: UIControl.State.normal)
        segment.layer.borderColor = UIColor.systemBlue.cgColor
        segment.layer.borderWidth = Metric.borderWidth
        return segment
    }()
    
    private lazy var addedButton: UIButton = {
        let button = UIButton()
        let configuration = UIImage.SymbolConfiguration(weight: .bold)
        let image = UIImage(systemName: CollectionViewNamespace.plus.name, withConfiguration: configuration)
        button.addTarget(self, action: #selector(moveProductRegistrationPage), for: .touchUpInside)
        button.setImage(image, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = createListLayout()
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return collectionView
    }()
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
        
        collectionView.prefetchDataSource = self
        collectionView.delegate = self
        collectionView.register(ListCollectionViewCell.self, forCellWithReuseIdentifier: CollectionViewNamespace.list.name)
        collectionView.register(GridCollectionViewCell.self, forCellWithReuseIdentifier: CollectionViewNamespace.grid.name)
        
        dataSource = configureDataSource(id: CollectionViewNamespace.list.name)
        self.snapshot.appendSections([.main])

        bind()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(true)
        
        self.snapshot.deleteAllItems()
        self.snapshot.appendSections([.main])
        productPageNumber = 1
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        viewModel.input.getInformation(pageNumber: Metric.firstPage)
    }
    
    // MARK: Method
    
    @objc private func moveProductRegistrationPage() {
        let registrationViewController = RegistrationViewController()
        navigationController?.pushViewController(registrationViewController, animated: true)
    }
    
    private func setUI() {
        view.backgroundColor = .white
        
        navigationItem.titleView = segmentedControl
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: addedButton)
        
        view.addSubview(collectionView)
        view.addSubview(loadingView)
        
        setCollectionViewConstraint()
    }
    
    private func setCollectionViewConstraint() {
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor)
        ])
    }

    private func bind() {
        viewModel.output.marketInformationPublisher
            .sink { productList in
                self.snapshot.appendItems(productList.pages)
                self.dataSource?.apply(self.snapshot, animatingDifferences: true)
            }.store(in: &cancellable)

        viewModel.output.isLoadingPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                if isLoading {
                    self.loadingView.startAnimating()
                } else {
                    self.loadingView.stopAnimating()
                }
            }
            .store(in: &cancellable)

        viewModel.output.alertPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                guard let self = self else { return }
                self.showCustomAlert(title: nil, message: error)
            }.store(in: &cancellable)

        viewModel.output.marketItemIdPublisher
            .sink { [weak self] itemId in
                guard let self = self else { return }
                let viewController = ProductDetailViewController(id: itemId)
                self.navigationController?.pushViewController(viewController, animated: true)
                self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
            }.store(in: &cancellable)
    }
    
    private func configureDataSource(id: String) -> DiffableDataSource? {
        dataSource = DiffableDataSource(collectionView: collectionView) { (collectionView: UICollectionView, indexPath: IndexPath, product: PageInformation) -> UICollectionViewCell? in
            switch id {
            case CollectionViewNamespace.list.name:
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CollectionViewNamespace.list.name, for: indexPath) as? ListCollectionViewCell else {
                    return ListCollectionViewCell()
                }
                cell.configureCell(product: product) { result in
                    switch result {
                    case .success(_):
                        return
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.showCustomAlert(title: nil, message: error.localizedDescription)
                        }
                    }
                }
                return cell
            default:
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CollectionViewNamespace.grid.name, for: indexPath) as? GridCollectionViewCell else {
                    return GridCollectionViewCell()
                }
                cell.configureCell(product: product) { result in
                    switch result {
                    case .success(_):
                        return
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.showCustomAlert(title: nil, message: error.localizedDescription)
                        }
                    }
                }
                return cell
            }
        }
        return dataSource
    }
    
    @objc private func handleSegmentChange() {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            collectionView.setCollectionViewLayout(createListLayout(), animated: true)
            dataSource = configureDataSource(id: CollectionViewNamespace.list.name)
            dataSource?.apply(snapshot, animatingDifferences: false)
            return
        default:
            collectionView.setCollectionViewLayout(createGridLayout(), animated: true)
            dataSource = configureDataSource(id: CollectionViewNamespace.grid.name)
            dataSource?.apply(snapshot, animatingDifferences: false)
            return
        }
    }
    
    private func createListLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(Metric.listItemWidth), heightDimension: .fractionalHeight(Metric.listItemHeight))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(Metric.listGroupWidth), heightDimension: .fractionalHeight(Metric.listGroupHeight))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: Metric.listGroupCount)
        group.contentInsets = NSDirectionalEdgeInsets(top: Metric.padding, leading: Metric.padding, bottom: Metric.padding, trailing: .zero)
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = Metric.listGroupSpacing
        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }
    
    private func createGridLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(Metric.gridItemWidth), heightDimension: .fractionalHeight(Metric.gridItemHeight))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(Metric.gridGroupWidth), heightDimension: .fractionalHeight(Metric.gridGroupHeight))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: Metric.gridGroupCount)
        group.interItemSpacing = .fixed(Metric.gridGroupSpacing)
        group.contentInsets = NSDirectionalEdgeInsets(top: Metric.padding, leading: Metric.padding, bottom: Metric.padding, trailing: Metric.padding)
        
        let section = NSCollectionLayoutSection(group: group)
        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }
}

// MARK: Extension

extension MainViewController: UICollectionViewDataSourcePrefetching {
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        guard let last = indexPaths.last else { return }
        let currentPage = (last.row / Metric.itemCount) + 1
        
        if currentPage == productPageNumber {
            self.loadingView.startAnimating()
            
            productPageNumber += 1
            viewModel.input.getInformation(pageNumber: currentPage)
        }
    }
}

extension MainViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let id = snapshot.itemIdentifiers[indexPath.row].id
        //let viewController = ProductDetailViewController(product: product)
        viewModel.input.pushToDetailView(indexPath: indexPath, id: id)

        
//        navigationController?.pushViewController(viewController, animated: true)
//        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

    }
}