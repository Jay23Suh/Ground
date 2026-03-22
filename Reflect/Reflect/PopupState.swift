import Foundation
import Combine

class PopupState: ObservableObject {
    static let shared = PopupState()
    @Published var question: String = ""
    @Published var category: String = ""

    private init() { refresh() }

    func refresh() {
        let (q, c) = Questions.pick()
        question = q
        category = c
    }
}
