//
//  TestHelpers.swift
//  TimeControlTests
//

import Foundation
@testable import TimeControl

func makeTodo(
    text: String = "Test task",
    isCompleted: Bool = false,
    estimatedTime: TimeInterval = 0,
    subtasks: [Subtask] = []
) -> TodoItem {
    TodoItem(text: text, isCompleted: isCompleted, estimatedTime: estimatedTime, subtasks: subtasks)
}

func makeSubtask(title: String = "Subtask", isCompleted: Bool = false) -> Subtask {
    Subtask(title: title, isCompleted: isCompleted)
}

func makeViewModel() -> (vm: TodoViewModel, url: URL) {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".json")
    let vm = TodoViewModel(storageURL: url)
    return (vm, url)
}
