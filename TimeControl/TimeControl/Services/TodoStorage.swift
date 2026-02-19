//
//  TodoStorage.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import Foundation

class TodoStorage {
    private static let storageURL: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("todos.json")
    }()
    
    static func save(todos: [TodoItem]) {
        var tasksDict: [String: [String: Any]] = [:]
        
        for todo in todos {
            var taskData: [String: Any] = [
                "title": todo.text,
                "index": todo.index,
                "isCompleted": todo.isCompleted,
                "totalTimeSpent": todo.totalTimeSpent,
                "description": todo.description,
                "isAdhoc": todo.isAdhoc,
                "fromWho": todo.fromWho,
                "estimatedTime": todo.estimatedTime,
                "createdAt": todo.createdAt,
                "notes": todo.notes
            ]
            
            if let lastStartTime = todo.lastStartTime {
                taskData["lastStartTime"] = lastStartTime.timeIntervalSince1970
            }
            
            if let dueDate = todo.dueDate {
                taskData["dueDate"] = dueDate.timeIntervalSince1970
            }
            
            if let startedAt = todo.startedAt {
                taskData["startedAt"] = startedAt
            }
            
            if let completedAt = todo.completedAt {
                taskData["completedAt"] = completedAt
            }
            
            var subtasksArray: [[String: Any]] = []
            for subtask in todo.subtasks {
                subtasksArray.append([
                    "id": subtask.id.uuidString,
                    "title": subtask.title,
                    "description": subtask.description,
                    "isCompleted": subtask.isCompleted,
                    "totalTimeSpent": subtask.totalTimeSpent
                ])
            }
            taskData["subtasks"] = subtasksArray
            
            tasksDict[todo.id.uuidString] = taskData
        }
        
        let jsonData: [String: Any] = ["tasks": tasksDict]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
            try data.write(to: storageURL)
        } catch {
            print("Error saving todos: \(error.localizedDescription)")
        }
    }
    
    static func load() -> [TodoItem] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let tasksDict = json?["tasks"] as? [String: [String: Any]] else {
                return []
            }
            
            var todos: [TodoItem] = []
            for (idString, taskData) in tasksDict {
                guard let id = UUID(uuidString: idString),
                      let title = taskData["title"] as? String,
                      let index = taskData["index"] as? Int else {
                    continue
                }
                
                let isCompleted = taskData["isCompleted"] as? Bool ?? false
                let totalTimeSpent = taskData["totalTimeSpent"] as? TimeInterval ?? 0
                let description = taskData["description"] as? String ?? ""
                let isAdhoc = taskData["isAdhoc"] as? Bool ?? false
                let fromWho = taskData["fromWho"] as? String ?? ""
                let estimatedTime = taskData["estimatedTime"] as? TimeInterval ?? 0
                let createdAt = taskData["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
                let startedAt = taskData["startedAt"] as? TimeInterval
                let completedAt = taskData["completedAt"] as? TimeInterval
                let notes = taskData["notes"] as? String ?? ""
                
                var lastStartTime: Date? = nil
                if let timestamp = taskData["lastStartTime"] as? TimeInterval {
                    lastStartTime = Date(timeIntervalSince1970: timestamp)
                }
                
                var dueDate: Date? = nil
                if let timestamp = taskData["dueDate"] as? TimeInterval {
                    dueDate = Date(timeIntervalSince1970: timestamp)
                }
                
                var subtasks: [Subtask] = []
                if let subtasksArray = taskData["subtasks"] as? [[String: Any]] {
                    for subtaskData in subtasksArray {
                        guard let subtaskIdString = subtaskData["id"] as? String,
                              let subtaskId = UUID(uuidString: subtaskIdString),
                              let subtaskTitle = subtaskData["title"] as? String else {
                            continue
                        }
                        let subtaskDescription = subtaskData["description"] as? String ?? ""
                        let subtaskIsCompleted = subtaskData["isCompleted"] as? Bool ?? false
                        let subtaskTotalTimeSpent = subtaskData["totalTimeSpent"] as? TimeInterval ?? 0
                        subtasks.append(Subtask(id: subtaskId, title: subtaskTitle, description: subtaskDescription, isCompleted: subtaskIsCompleted, totalTimeSpent: subtaskTotalTimeSpent))
                    }
                }
                
                let todo = TodoItem(id: id, text: title, isCompleted: isCompleted, index: index, totalTimeSpent: totalTimeSpent, lastStartTime: lastStartTime, description: description, dueDate: dueDate, isAdhoc: isAdhoc, fromWho: fromWho, estimatedTime: estimatedTime, subtasks: subtasks, createdAt: createdAt, startedAt: startedAt, completedAt: completedAt, notes: notes)
                todos.append(todo)
            }
            
            return todos.sorted { $0.index < $1.index }
        } catch {
            print("Error loading todos: \(error.localizedDescription)")
            return []
        }
    }
}
