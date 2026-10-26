import Foundation

/// Leituras pontuais da cena do editor (JSON `.excalidraw`) sem depender do
/// formato completo dos elementos.
public enum SceneInspector {
    /// Ids das imagens que algum elemento usa, inclusive elementos apagados
    /// (o desfazer ainda pode trazê-los de volta).
    public static func referencedFileIDs(in scene: String) -> Set<String> {
        guard let elements = elements(in: scene) else { return [] }
        return Set(elements.compactMap { $0["fileId"] as? String })
    }

    /// Quantos elementos visíveis a cena tem.
    public static func visibleElementCount(in scene: String) -> Int {
        elements(in: scene)?.filter { ($0["isDeleted"] as? Bool) != true }.count ?? 0
    }

    private static func elements(in scene: String) -> [[String: Any]]? {
        guard let data = scene.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object["elements"] as? [[String: Any]]
    }
}
