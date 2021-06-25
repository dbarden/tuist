import TSCBasic
import TuistGraph
import TuistSupport
import XCTest

@testable import TuistDependencies
@testable import TuistDependenciesTesting
@testable import TuistSupportTesting

final class DependenciesControllerTests: TuistUnitTestCase {
    private var subject: DependenciesController!

    private var carthageInteractor: MockCarthageInteractor!
    private var cocoaPodsInteractor: MockCocoaPodsInteractor!
    private var swiftPackageManagerInteractor: MockSwiftPackageManagerInteractor!
    private var dependenciesGraphController: MockDependenciesGraphController!

    override func setUp() {
        super.setUp()

        carthageInteractor = MockCarthageInteractor()
        cocoaPodsInteractor = MockCocoaPodsInteractor()
        swiftPackageManagerInteractor = MockSwiftPackageManagerInteractor()
        dependenciesGraphController = MockDependenciesGraphController()

        subject = DependenciesController(
            carthageInteractor: carthageInteractor,
            cocoaPodsInteractor: cocoaPodsInteractor,
            swiftPackageManagerInteractor: swiftPackageManagerInteractor,
            dependenciesGraphController: dependenciesGraphController
        )
    }

    override func tearDown() {
        subject = nil

        carthageInteractor = nil
        cocoaPodsInteractor = nil
        swiftPackageManagerInteractor = nil
        dependenciesGraphController = nil

        super.tearDown()
    }

    // MARK: - Fetch

    func test_fetch_carthage() throws {
        // Given
        let rootPath = try temporaryPath()
        let dependenciesDirectoryPath = rootPath
            .appending(component: Constants.tuistDirectoryName)
            .appending(component: Constants.DependenciesDirectory.name)

        let platforms: Set<Platform> = [.iOS]
        let carthageDependencies = CarthageDependencies(
            [
                .github(path: "Moya", requirement: .exact("1.1.1")),
                .github(path: "RxSwift", requirement: .exact("2.0.0")),
            ]
        )
        let dependencies = Dependencies(
            carthage: carthageDependencies,
            swiftPackageManager: nil,
            platforms: platforms
        )

        let graph = DependenciesGraph.testXCFramework(name: "Name")

        carthageInteractor.installStub = { arg0, arg1, arg2, arg3 in
            XCTAssertEqual(arg0, dependenciesDirectoryPath)
            XCTAssertEqual(arg1, carthageDependencies)
            XCTAssertEqual(arg2, platforms)
            XCTAssertFalse(arg3)

            return graph
        }
        dependenciesGraphController.saveStub = { arg0, arg1 in
            XCTAssertEqual(graph, arg0)
            XCTAssertEqual(rootPath, arg1)
        }

        // When
        try subject.fetch(at: rootPath, dependencies: dependencies, swiftVersion: nil)

        // Then
        XCTAssertFalse(carthageInteractor.invokedClean)
        XCTAssertTrue(carthageInteractor.invokedInstall)

        XCTAssertTrue(swiftPackageManagerInteractor.invokedClean)
        XCTAssertFalse(swiftPackageManagerInteractor.invokedInstall)

        XCTAssertFalse(cocoaPodsInteractor.invokedClean)
        XCTAssertFalse(cocoaPodsInteractor.invokedInstall)

        XCTAssertTrue(dependenciesGraphController.invokedSave)
        XCTAssertFalse(dependenciesGraphController.invokedClean)
    }

    func test_fetch_swiftPackageManger() throws {
        // Given
        let rootPath = try temporaryPath()
        let dependenciesDirectoryPath = rootPath
            .appending(component: Constants.tuistDirectoryName)
            .appending(component: Constants.DependenciesDirectory.name)

        let platforms: Set<Platform> = [.iOS]
        let swiftPackageManagerDependencies = SwiftPackageManagerDependencies(
            [
                .remote(url: "Moya", requirement: .exact("2.3.4")),
                .remote(url: "Alamofire", requirement: .upToNextMajor("5.0.0")),
            ]
        )
        let dependencies = Dependencies(
            carthage: nil,
            swiftPackageManager: swiftPackageManagerDependencies,
            platforms: platforms
        )
        let swiftVersion = "5.4.0"

        swiftPackageManagerInteractor.installStub = { arg0, arg1, arg2, arg3, arg4 in
            XCTAssertEqual(arg0, dependenciesDirectoryPath)
            XCTAssertEqual(arg1, swiftPackageManagerDependencies)
            XCTAssertEqual(arg2, [.iOS])
            XCTAssertFalse(arg3)
            XCTAssertEqual(arg4, swiftVersion)
            return .test()
        }
        dependenciesGraphController.saveStub = { arg0, arg1 in
            XCTAssertEqual(.test(), arg0)
            XCTAssertEqual(rootPath, arg1)
        }

        // When
        try subject.fetch(at: rootPath, dependencies: dependencies, swiftVersion: swiftVersion)

        // Then
        XCTAssertFalse(swiftPackageManagerInteractor.invokedClean)
        XCTAssertTrue(swiftPackageManagerInteractor.invokedInstall)

        XCTAssertTrue(carthageInteractor.invokedClean)
        XCTAssertFalse(carthageInteractor.invokedInstall)

        XCTAssertFalse(cocoaPodsInteractor.invokedClean)
        XCTAssertFalse(cocoaPodsInteractor.invokedInstall)

        XCTAssertFalse(dependenciesGraphController.invokedSave)
        XCTAssertTrue(dependenciesGraphController.invokedClean)
    }

    func test_fetch_carthage_swiftPackageManger() throws {
        // Given
        let rootPath = try temporaryPath()
        let dependenciesDirectoryPath = rootPath
            .appending(component: Constants.tuistDirectoryName)
            .appending(component: Constants.DependenciesDirectory.name)

        let platforms: Set<Platform> = [.iOS]
        let carthageDependencies = CarthageDependencies(
            [
                .github(path: "Moya", requirement: .exact("1.1.1")),
                .github(path: "RxSwift", requirement: .exact("2.0.0")),
            ]
        )
        let swiftPackageManagerDependencies = SwiftPackageManagerDependencies(
            [
                .remote(url: "Moya", requirement: .exact("2.3.4")),
                .remote(url: "Alamofire", requirement: .upToNextMajor("5.0.0")),
            ]
        )
        let dependencies = Dependencies(
            carthage: carthageDependencies,
            swiftPackageManager: swiftPackageManagerDependencies,
            platforms: platforms
        )
        let swiftVersion = "5.4.0"
        let carthageGraph = DependenciesGraph.testXCFramework(name: "Carthage")
        let spmGraph = DependenciesGraph.testXCFramework(name: "SPM")

        carthageInteractor.installStub = { arg0, arg1, arg2, arg3 in
            XCTAssertEqual(arg0, dependenciesDirectoryPath)
            XCTAssertEqual(arg1, carthageDependencies)
            XCTAssertEqual(arg2, platforms)
            XCTAssertFalse(arg3)

            return carthageGraph
        }
        swiftPackageManagerInteractor.installStub = { arg0, arg1, arg2, arg3, arg4 in
            XCTAssertEqual(arg0, dependenciesDirectoryPath)
            XCTAssertEqual(arg1, swiftPackageManagerDependencies)
            XCTAssertEqual(arg2, [.iOS])
            XCTAssertFalse(arg3)
            XCTAssertEqual(arg4, swiftVersion)
            return spmGraph
        }
        dependenciesGraphController.saveStub = { arg0, arg1 in
            XCTAssertEqual(
                arg0,
                .init(externalDependencies: [
                    "Carthage": carthageGraph.externalDependencies.values.first!,
                    "SPM": spmGraph.externalDependencies.values.first!,
                ])
            )
            XCTAssertEqual(rootPath, arg1)
        }

        // When
        try subject.fetch(at: rootPath, dependencies: dependencies, swiftVersion: swiftVersion)

        // Then
        XCTAssertTrue(carthageInteractor.invokedInstall)
        XCTAssertFalse(carthageInteractor.invokedClean)

        XCTAssertTrue(swiftPackageManagerInteractor.invokedInstall)
        XCTAssertFalse(swiftPackageManagerInteractor.invokedClean)

        XCTAssertFalse(cocoaPodsInteractor.invokedClean)
        XCTAssertFalse(cocoaPodsInteractor.invokedInstall)

        XCTAssertTrue(dependenciesGraphController.invokedSave)
        XCTAssertFalse(dependenciesGraphController.invokedClean)
    }

    func test_fetch_carthage_swiftPackageManger_throws_when_duplicatedDependency() throws {
        // Given
        let rootPath = try temporaryPath()
        let dependencies = Dependencies(
            carthage: .init([
                .github(path: "Moya", requirement: .exact("1.1.1")),
            ]),
            swiftPackageManager: .init([
                .remote(url: "Moya", requirement: .exact("2.3.4")),
            ]),
            platforms: [.iOS]
        )
        let carthageGraph = DependenciesGraph.testXCFramework(name: "Duplicated", path: rootPath.appending(component: "Carthage"))
        let spmGraph = DependenciesGraph.testXCFramework(name: "Duplicated", path: rootPath.appending(component: "SPM"))

        carthageInteractor.installStub = { _, _, _, _ in
            carthageGraph
        }
        swiftPackageManagerInteractor.installStub = { _, _, _, _, _ in
            spmGraph
        }

        // When / Then
        XCTAssertThrowsSpecific(
            try subject.fetch(at: rootPath, dependencies: dependencies, swiftVersion: nil),
            DependenciesGraphError.duplicatedDependency(
                "Duplicated",
                carthageGraph.externalDependencies.values.first!,
                spmGraph.externalDependencies.values.first!
            )
        )

        // Then
        XCTAssertTrue(carthageInteractor.invokedInstall)
        XCTAssertFalse(carthageInteractor.invokedClean)

        XCTAssertTrue(swiftPackageManagerInteractor.invokedInstall)
        XCTAssertFalse(swiftPackageManagerInteractor.invokedClean)

        XCTAssertFalse(cocoaPodsInteractor.invokedClean)
        XCTAssertFalse(cocoaPodsInteractor.invokedInstall)

        XCTAssertFalse(dependenciesGraphController.invokedSave)
        XCTAssertFalse(dependenciesGraphController.invokedClean)
    }

    func test_fetch_throws_when_noPlatforms() throws {
        // Given
        let rootPath = try temporaryPath()

        let dependencies = Dependencies(
            carthage: .init([]),
            swiftPackageManager: .init([]),
            platforms: []
        )

        // When / Then
        XCTAssertThrowsSpecific(
            try subject.fetch(at: rootPath, dependencies: dependencies, swiftVersion: nil),
            DependenciesControllerError.noPlatforms
        )
    }

    func test_fetch_no_dependencies() throws {
        // Given
        let rootPath = try temporaryPath()

        let dependencies = Dependencies(
            carthage: .init([]),
            swiftPackageManager: .init([]),
            platforms: [.iOS]
        )

        // When
        try subject.fetch(at: rootPath, dependencies: dependencies, swiftVersion: nil)

        // Then
        XCTAssertFalse(carthageInteractor.invokedInstall)
        XCTAssertTrue(carthageInteractor.invokedClean)

        XCTAssertFalse(swiftPackageManagerInteractor.invokedInstall)
        XCTAssertTrue(swiftPackageManagerInteractor.invokedClean)

        XCTAssertFalse(cocoaPodsInteractor.invokedClean)
        XCTAssertFalse(cocoaPodsInteractor.invokedInstall)

        XCTAssertFalse(dependenciesGraphController.invokedSave)
        XCTAssertTrue(dependenciesGraphController.invokedClean)
    }

    // MARK: - Update

    func test_update_carthage() throws {
        // Given
        let rootPath = try temporaryPath()
        let dependenciesDirectoryPath = rootPath
            .appending(component: Constants.tuistDirectoryName)
            .appending(component: Constants.DependenciesDirectory.name)

        let platforms: Set<Platform> = [.iOS]
        let carthageDependencies = CarthageDependencies(
            [
                .github(path: "Moya", requirement: .exact("1.1.1")),
                .github(path: "RxSwift", requirement: .exact("2.0.0")),
            ]
        )
        let dependencies = Dependencies(
            carthage: carthageDependencies,
            swiftPackageManager: nil,
            platforms: platforms
        )
        let graph = DependenciesGraph.testXCFramework(name: "Name")

        carthageInteractor.installStub = { arg0, arg1, arg2, arg3 in
            XCTAssertEqual(arg0, dependenciesDirectoryPath)
            XCTAssertEqual(arg1, carthageDependencies)
            XCTAssertEqual(arg2, platforms)
            XCTAssertTrue(arg3)

            return graph
        }
        dependenciesGraphController.saveStub = { arg0, arg1 in
            XCTAssertEqual(graph, arg0)
            XCTAssertEqual(rootPath, arg1)
        }

        // When
        try subject.update(at: rootPath, dependencies: dependencies, swiftVersion: nil)

        // Then
        XCTAssertFalse(carthageInteractor.invokedClean)
        XCTAssertTrue(carthageInteractor.invokedInstall)

        XCTAssertTrue(swiftPackageManagerInteractor.invokedClean)
        XCTAssertFalse(swiftPackageManagerInteractor.invokedInstall)

        XCTAssertFalse(cocoaPodsInteractor.invokedClean)
        XCTAssertFalse(cocoaPodsInteractor.invokedInstall)

        XCTAssertTrue(dependenciesGraphController.invokedSave)
        XCTAssertFalse(dependenciesGraphController.invokedClean)
    }

    func test_update_swiftPackageManger() throws {
        // Given
        let rootPath = try temporaryPath()
        let dependenciesDirectoryPath = rootPath
            .appending(component: Constants.tuistDirectoryName)
            .appending(component: Constants.DependenciesDirectory.name)

        let platforms: Set<Platform> = [.iOS]
        let swiftPackageManagerDependencies = SwiftPackageManagerDependencies(
            [
                .remote(url: "Moya", requirement: .exact("2.3.4")),
                .remote(url: "Alamofire", requirement: .upToNextMajor("5.0.0")),
            ]
        )
        let dependencies = Dependencies(
            carthage: nil,
            swiftPackageManager: swiftPackageManagerDependencies,
            platforms: platforms
        )
        let swiftVersion = "5.4.0"

        swiftPackageManagerInteractor.installStub = { arg0, arg1, arg2, arg3, arg4 in
            XCTAssertEqual(arg0, dependenciesDirectoryPath)
            XCTAssertEqual(arg1, swiftPackageManagerDependencies)
            XCTAssertEqual(arg2, [.iOS])
            XCTAssertTrue(arg3)
            XCTAssertEqual(arg4, swiftVersion)
            return .test()
        }
        dependenciesGraphController.saveStub = { arg0, arg1 in
            XCTAssertEqual(.test(), arg0)
            XCTAssertEqual(rootPath, arg1)
        }

        // When
        try subject.update(at: rootPath, dependencies: dependencies, swiftVersion: swiftVersion)

        // Then
        XCTAssertFalse(swiftPackageManagerInteractor.invokedClean)
        XCTAssertTrue(swiftPackageManagerInteractor.invokedInstall)

        XCTAssertTrue(carthageInteractor.invokedClean)
        XCTAssertFalse(carthageInteractor.invokedInstall)

        XCTAssertFalse(cocoaPodsInteractor.invokedClean)
        XCTAssertFalse(cocoaPodsInteractor.invokedInstall)

        XCTAssertFalse(dependenciesGraphController.invokedSave)
        XCTAssertTrue(dependenciesGraphController.invokedClean)
    }

    func test_update_carthage_swiftPackageManger() throws {
        // Given
        let rootPath = try temporaryPath()
        let dependenciesDirectoryPath = rootPath
            .appending(component: Constants.tuistDirectoryName)
            .appending(component: Constants.DependenciesDirectory.name)

        let platforms: Set<Platform> = [.iOS]
        let carthageDependencies = CarthageDependencies(
            [
                .github(path: "Moya", requirement: .exact("1.1.1")),
                .github(path: "RxSwift", requirement: .exact("2.0.0")),
            ]
        )
        let swiftPackageManagerDependencies = SwiftPackageManagerDependencies(
            [
                .remote(url: "Moya", requirement: .exact("2.3.4")),
                .remote(url: "Alamofire", requirement: .upToNextMajor("5.0.0")),
            ]
        )
        let dependencies = Dependencies(
            carthage: carthageDependencies,
            swiftPackageManager: swiftPackageManagerDependencies,
            platforms: platforms
        )
        let swiftVersion = "5.4.0"
        let graph = DependenciesGraph.testXCFramework(name: "Name")

        carthageInteractor.installStub = { arg0, arg1, arg2, arg3 in
            XCTAssertEqual(arg0, dependenciesDirectoryPath)
            XCTAssertEqual(arg1, carthageDependencies)
            XCTAssertEqual(arg2, platforms)
            XCTAssertTrue(arg3)

            return graph
        }
        swiftPackageManagerInteractor.installStub = { arg0, arg1, arg2, arg3, arg4 in
            XCTAssertEqual(arg0, dependenciesDirectoryPath)
            XCTAssertEqual(arg1, swiftPackageManagerDependencies)
            XCTAssertEqual(arg2, [.iOS])
            XCTAssertTrue(arg3)
            XCTAssertEqual(arg4, swiftVersion)
            return .test()
        }
        dependenciesGraphController.saveStub = { arg0, arg1 in
            XCTAssertEqual(graph, arg0)
            XCTAssertEqual(rootPath, arg1)
        }

        // When
        try subject.update(at: rootPath, dependencies: dependencies, swiftVersion: swiftVersion)

        // Then
        XCTAssertFalse(carthageInteractor.invokedClean)
        XCTAssertTrue(carthageInteractor.invokedInstall)

        XCTAssertFalse(swiftPackageManagerInteractor.invokedClean)
        XCTAssertTrue(swiftPackageManagerInteractor.invokedInstall)

        XCTAssertFalse(cocoaPodsInteractor.invokedClean)
        XCTAssertFalse(cocoaPodsInteractor.invokedInstall)

        XCTAssertTrue(dependenciesGraphController.invokedSave)
        XCTAssertFalse(dependenciesGraphController.invokedClean)
    }

    func test_update_throws_when_noPlatforms() throws {
        // Given
        let rootPath = try temporaryPath()

        let dependencies = Dependencies(
            carthage: .init([]),
            swiftPackageManager: .init([]),
            platforms: []
        )

        // When / Then
        XCTAssertThrowsSpecific(
            try subject.update(at: rootPath, dependencies: dependencies, swiftVersion: nil),
            DependenciesControllerError.noPlatforms
        )
    }

    func test_update_no_dependencies() throws {
        // Given
        let rootPath = try temporaryPath()

        let dependencies = Dependencies(
            carthage: .init([]),
            swiftPackageManager: .init([]),
            platforms: [.iOS]
        )

        // When
        try subject.update(at: rootPath, dependencies: dependencies, swiftVersion: nil)

        // Then
        XCTAssertFalse(carthageInteractor.invokedInstall)
        XCTAssertTrue(carthageInteractor.invokedClean)

        XCTAssertFalse(swiftPackageManagerInteractor.invokedInstall)
        XCTAssertTrue(swiftPackageManagerInteractor.invokedClean)

        XCTAssertFalse(cocoaPodsInteractor.invokedClean)
        XCTAssertFalse(cocoaPodsInteractor.invokedInstall)

        XCTAssertFalse(dependenciesGraphController.invokedSave)
        XCTAssertTrue(dependenciesGraphController.invokedClean)
    }
}
