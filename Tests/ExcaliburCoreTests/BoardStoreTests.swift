import XCTest
@testable import ExcaliburCore

final class BoardStoreTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExcaliburFormsTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func image(_ id: String) -> Data {
        Data(#"{"id":"\#(id)","dataURL":"data:image/png;base64,AAAA","mimeType":"image/png","created":1}"#.utf8)
    }

    private func scene(fileIDs: [String], deleted: Set<String> = []) -> String {
        let elements = fileIDs.map { id in
            #"{"type":"image","id":"el-\#(id)","fileId":"\#(id)","isDeleted":\#(deleted.contains(id))}"#
        }
        return #"{"type":"excalidraw","elements":[\#(elements.joined(separator: ","))],"appState":{}}"#
    }

    func testCreatesRenamesAndPersistsAcrossLaunches() throws {
        let store = try BoardStore(root: root, usesTrash: false)
        let board = try store.create(name: "  Referências  ")
        XCTAssertEqual(board.name, "Referências")
        try store.rename(id: board.id, to: "Telas")

        let reopened = try BoardStore(root: root, usesTrash: false)
        XCTAssertEqual(reopened.boards.map(\.name), ["Telas"])
    }

    func testRejectsEmptyNamesAndUnsafeIDs() throws {
        let store = try BoardStore(root: root, usesTrash: false)
        XCTAssertThrowsError(try store.create(name: "   "))
        XCTAssertThrowsError(try store.loadContent(id: "../escape")) { error in
            XCTAssertEqual(error as? BoardStoreError, .invalidIdentifier("../escape"))
        }
        XCTAssertThrowsError(try store.loadContent(id: "missing")) { error in
            XCTAssertEqual(error as? BoardStoreError, .boardNotFound("missing"))
        }
    }

    func testSavesSceneAndImagesAndRestoresThem() throws {
        let store = try BoardStore(root: root, usesTrash: false)
        let board = try store.create(name: "A")
        XCTAssertEqual(try store.loadContent(id: board.id), BoardContent(scene: nil, files: []))

        try store.save(id: board.id, scene: scene(fileIDs: ["img1"]), files: [image("img1")])
        let reopened = try BoardStore(root: root, usesTrash: false)
        let content = try reopened.loadContent(id: board.id)
        XCTAssertEqual(content.scene, scene(fileIDs: ["img1"]))
        XCTAssertEqual(content.files, [image("img1")])
    }

    func testRejectsImagesWithUnsafeIDs() throws {
        let store = try BoardStore(root: root, usesTrash: false)
        let board = try store.create(name: "A")
        XCTAssertThrowsError(
            try store.save(id: board.id, scene: "{}", files: [image("../../evil")])
        )
        XCTAssertThrowsError(
            try store.save(id: board.id, scene: "{}", files: [Data("not json".utf8)])
        )
    }

    func testPrunesOnlyUnreferencedImages() throws {
        let store = try BoardStore(root: root, usesTrash: false)
        let board = try store.create(name: "A")
        try store.save(
            id: board.id,
            scene: scene(fileIDs: ["kept", "deleted", "gone"]),
            files: [image("kept"), image("deleted"), image("gone")]
        )
        // "gone" saiu da cena; "deleted" segue alcançável pelo desfazer
        try store.save(id: board.id, scene: scene(fileIDs: ["kept", "deleted"], deleted: ["deleted"]), files: [])
        let ids = try store.loadContent(id: board.id).files.compactMap {
            (try? JSONSerialization.jsonObject(with: $0) as? [String: Any])?["id"] as? String
        }
        XCTAssertEqual(Set(ids), ["kept", "deleted"])
    }

    func testDuplicateIsIndependent() throws {
        let store = try BoardStore(root: root, usesTrash: false)
        let board = try store.create(name: "A")
        try store.save(id: board.id, scene: scene(fileIDs: ["img"]), files: [image("img")])
        let copy = try store.duplicate(id: board.id, name: "A (cópia)")
        XCTAssertEqual(store.boards.map(\.id), [board.id, copy.id])

        try store.save(id: copy.id, scene: scene(fileIDs: []), files: [])
        XCTAssertEqual(try store.loadContent(id: board.id).scene, scene(fileIDs: ["img"]))
        XCTAssertEqual(try store.loadContent(id: copy.id).files, [])
    }

    func testDeleteLeavesOtherBoardsIntact() throws {
        let store = try BoardStore(root: root, usesTrash: false)
        let first = try store.create(name: "A")
        let second = try store.create(name: "B")
        try store.save(id: second.id, scene: scene(fileIDs: ["img"]), files: [image("img")])

        try store.delete(id: first.id)
        let reopened = try BoardStore(root: root, usesTrash: false)
        XCTAssertEqual(reopened.boards.map(\.id), [second.id])
        XCTAssertEqual(try reopened.loadContent(id: second.id).files.count, 1)
    }

    func testRecoversBoardsMissingFromALostIndex() throws {
        let store = try BoardStore(root: root, usesTrash: false)
        let board = try store.create(name: "A")
        try store.save(id: board.id, scene: scene(fileIDs: []), files: [])
        try Data("corrompido".utf8).write(to: root.appendingPathComponent("boards.json"))

        let reopened = try BoardStore(root: root, usesTrash: false)
        XCTAssertEqual(reopened.boards.map(\.id), [board.id])
        XCTAssertEqual(reopened.boards.first?.name, "Quadro recuperado")
        XCTAssertNotNil(try reopened.loadContent(id: board.id).scene)
    }

    func testSceneInspector() {
        let json = scene(fileIDs: ["a", "b"], deleted: ["b"])
        XCTAssertEqual(SceneInspector.referencedFileIDs(in: json), ["a", "b"])
        XCTAssertEqual(SceneInspector.visibleElementCount(in: json), 1)
        XCTAssertEqual(SceneInspector.referencedFileIDs(in: "garbage"), [])
    }

    func testSafeIdentifiers() {
        XCTAssertTrue(Board.isSafeIdentifier("a1-B_2"))
        XCTAssertFalse(Board.isSafeIdentifier(""))
        XCTAssertFalse(Board.isSafeIdentifier("a/b"))
        XCTAssertFalse(Board.isSafeIdentifier(".."))
        XCTAssertFalse(Board.isSafeIdentifier("ação"))
    }
}
