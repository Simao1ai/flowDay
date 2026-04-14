import Testing
import Foundation
@testable import Flow_Day_ios

// MARK: - FDTask Tests

@Suite("FDTask Model Tests")
struct FDTaskTests {

    @Test("FDTask initializes with correct defaults")
    func taskInitialization() {
        let task = FDTask(title: "Test Task", notes: "", priority: .medium, isCompleted: false, isDeleted: false)

        #expect(task.title == "Test Task")
        #expect(task.notes == "")
        #expect(task.priority == .medium)
        #expect(task.isCompleted == false)
        #expect(task.isDeleted == false)
        #expect(task.labels == [])
        #expect(task.subtasks == [])
        #expect(task.startDate == nil)
        #expect(task.dueDate == nil)
    }

    @Test("Complete sets isCompleted to true")
    func completeTask() {
        var task = FDTask(title: "Test Task", notes: "", priority: .high, isCompleted: false, isDeleted: false)
        task.complete()
        #expect(task.isCompleted == true)
    }

    @Test("Uncomplete sets isCompleted to false")
    func uncompleteTask() {
        var task = FDTask(title: "Test Task", notes: "", priority: .high, isCompleted: true, isDeleted: false)
        task.uncomplete()
        #expect(task.isCompleted == false)
    }

    @Test("Toggle completion multiple times works correctly")
    func toggleCompletion() {
        var task = FDTask(title: "Test Task", notes: "", priority: .medium, isCompleted: false, isDeleted: false)

        task.complete()
        #expect(task.isCompleted == true)

        task.uncomplete()
        #expect(task.isCompleted == false)

        task.complete()
        #expect(task.isCompleted == true)
    }

    @Test("Soft delete marks isDeleted without removing data")
    func softDeleteTask() {
        var task = FDTask(title: "Important Task", notes: "Keep this", priority: .urgent, isCompleted: false, isDeleted: false)
        task.softDelete()

        #expect(task.isDeleted == true)
        #expect(task.title == "Important Task")
        #expect(task.notes == "Keep this")
    }

    @Test("Restore unmarks isDeleted")
    func restoreTask() {
        var task = FDTask(title: "Restored Task", notes: "", priority: .medium, isCompleted: false, isDeleted: true)
        task.restore()

        #expect(task.isDeleted == false)
    }

    @Test("isOverdue is true when dueDate is in the past")
    func isOverdueWithPastDate() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        var task = FDTask(title: "Overdue Task", notes: "", priority: .high, isCompleted: false, isDeleted: false)
        task.dueDate = yesterday

        #expect(task.isOverdue == true)
    }

    @Test("isOverdue is false when dueDate is in the future")
    func isOverdueWithFutureDate() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        var task = FDTask(title: "Future Task", notes: "", priority: .medium, isCompleted: false, isDeleted: false)
        task.dueDate = tomorrow

        #expect(task.isOverdue == false)
    }

    @Test("isOverdue is false for completed tasks")
    func isOverdueIgnoredForCompletedTasks() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        var task = FDTask(title: "Completed Overdue", notes: "", priority: .medium, isCompleted: true, isDeleted: false)
        task.dueDate = yesterday

        #expect(task.isOverdue == false)
    }

    @Test("isScheduledToday is true for tasks scheduled today")
    func isScheduledTodayTrue() {
        var task = FDTask(title: "Today Task", notes: "", priority: .medium, isCompleted: false, isDeleted: false)
        task.scheduledTime = Date()

        #expect(task.isScheduledToday == true)
    }

    @Test("isScheduledToday is false for tasks scheduled tomorrow")
    func isScheduledTodayFalse() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        var task = FDTask(title: "Tomorrow Task", notes: "", priority: .medium, isCompleted: false, isDeleted: false)
        task.scheduledTime = tomorrow

        #expect(task.isScheduledToday == false)
    }

    @Test("subtaskProgress calculates correctly with active subtasks")
    func subtaskProgressCalculation() {
        var task = FDTask(title: "Task with Subtasks", notes: "", priority: .medium, isCompleted: false, isDeleted: false)

        var subtask1 = FDSubtask(title: "Sub 1", isCompleted: true)
        var subtask2 = FDSubtask(title: "Sub 2", isCompleted: false)
        var subtask3 = FDSubtask(title: "Sub 3", isCompleted: true)

        task.subtasks = [subtask1, subtask2, subtask3]

        // 2 out of 3 completed = ~0.667
        #expect(task.subtaskProgress >= 0.66 && task.subtaskProgress <= 0.67)
    }

    @Test("subtaskProgress is zero when no subtasks")
    func subtaskProgressZeroWithNoSubtasks() {
        let task = FDTask(title: "No Subtasks", notes: "", priority: .medium, isCompleted: false, isDeleted: false)
        #expect(task.subtaskProgress == 0.0)
    }

    @Test("subtaskProgress is one when all subtasks completed")
    func subtaskProgressOneHundred() {
        var task = FDTask(title: "All Done", notes: "", priority: .medium, isCompleted: false, isDeleted: false)

        var subtask1 = FDSubtask(title: "Sub 1", isCompleted: true)
        var subtask2 = FDSubtask(title: "Sub 2", isCompleted: true)

        task.subtasks = [subtask1, subtask2]

        #expect(task.subtaskProgress == 1.0)
    }

    @Test("activeSubtasks filters out completed ones")
    func activeSubtasksFilter() {
        var task = FDTask(title: "Task", notes: "", priority: .medium, isCompleted: false, isDeleted: false)

        var subtask1 = FDSubtask(title: "Active 1", isCompleted: false)
        var subtask2 = FDSubtask(title: "Done", isCompleted: true)
        var subtask3 = FDSubtask(title: "Active 2", isCompleted: false)

        task.subtasks = [subtask1, subtask2, subtask3]

        #expect(task.activeSubtasks.count == 2)
        #expect(task.activeSubtasks[0].title == "Active 1")
        #expect(task.activeSubtasks[1].title == "Active 2")
    }

    @Test("Priority ordering follows correct enum order")
    func priorityOrdering() {
        #expect(TaskPriority.urgent < TaskPriority.high)
        #expect(TaskPriority.high < TaskPriority.medium)
        #expect(TaskPriority.medium < TaskPriority.none)
    }

    @Test("TaskPriority cases are all present and comparable")
    func priorityCaseIterable() {
        let allCases = TaskPriority.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.urgent))
        #expect(allCases.contains(.high))
        #expect(allCases.contains(.medium))
        #expect(allCases.contains(.none))
    }
}

// MARK: - FDProject Tests

@Suite("FDProject Model Tests")
struct FDProjectTests {

    @Test("FDProject initializes with correct defaults")
    func projectInitialization() {
        let project = FDProject(name: "Work", colorHex: "#FF0000", tasks: [], isArchived: false, isFavorite: false)

        #expect(project.name == "Work")
        #expect(project.colorHex == "#FF0000")
        #expect(project.tasks == [])
        #expect(project.isArchived == false)
        #expect(project.isFavorite == false)
    }

    @Test("activeTasks filters out completed and deleted tasks")
    func activeTasksFilter() {
        var project = FDProject(name: "Project", colorHex: "#0000FF", tasks: [], isArchived: false, isFavorite: false)

        var task1 = FDTask(title: "Active", notes: "", priority: .high, isCompleted: false, isDeleted: false)
        var task2 = FDTask(title: "Completed", notes: "", priority: .medium, isCompleted: true, isDeleted: false)
        var task3 = FDTask(title: "Deleted", notes: "", priority: .medium, isCompleted: false, isDeleted: true)
        var task4 = FDTask(title: "Active 2", notes: "", priority: .low, isCompleted: false, isDeleted: false)

        project.tasks = [task1, task2, task3, task4]

        #expect(project.activeTasks.count == 2)
        #expect(project.activeTasks[0].title == "Active")
        #expect(project.activeTasks[1].title == "Active 2")
    }

    @Test("completedTasks returns only completed non-deleted tasks")
    func completedTasksFilter() {
        var project = FDProject(name: "Project", colorHex: "#00FF00", tasks: [], isArchived: false, isFavorite: false)

        var task1 = FDTask(title: "Done 1", notes: "", priority: .high, isCompleted: true, isDeleted: false)
        var task2 = FDTask(title: "Active", notes: "", priority: .medium, isCompleted: false, isDeleted: false)
        var task3 = FDTask(title: "Done but deleted", notes: "", priority: .medium, isCompleted: true, isDeleted: true)
        var task4 = FDTask(title: "Done 2", notes: "", priority: .medium, isCompleted: true, isDeleted: false)

        project.tasks = [task1, task2, task3, task4]

        #expect(project.completedTasks.count == 2)
        #expect(project.completedTasks[0].title == "Done 1")
        #expect(project.completedTasks[1].title == "Done 2")
    }

    @Test("completionRate calculates correctly with mixed tasks")
    func completionRateCalculation() {
        var project = FDProject(name: "Project", colorHex: "#FFFF00", tasks: [], isArchived: false, isFavorite: false)

        var task1 = FDTask(title: "Done", notes: "", priority: .high, isCompleted: true, isDeleted: false)
        var task2 = FDTask(title: "Done", notes: "", priority: .medium, isCompleted: true, isDeleted: false)
        var task3 = FDTask(title: "Active", notes: "", priority: .medium, isCompleted: false, isDeleted: false)
        var task4 = FDTask(title: "Active", notes: "", priority: .low, isCompleted: false, isDeleted: false)

        project.tasks = [task1, task2, task3, task4]

        // 2 completed out of 4 total = 0.5
        #expect(project.completionRate == 0.5)
    }

    @Test("completionRate is zero with no tasks")
    func completionRateZeroWithNoTasks() {
        let project = FDProject(name: "Empty", colorHex: "#AAAAAA", tasks: [], isArchived: false, isFavorite: false)
        #expect(project.completionRate == 0.0)
    }

    @Test("completionRate is one when all tasks completed")
    func completionRateOneHundred() {
        var project = FDProject(name: "Done", colorHex: "#FFFFFF", tasks: [], isArchived: false, isFavorite: false)

        var task1 = FDTask(title: "Done 1", notes: "", priority: .high, isCompleted: true, isDeleted: false)
        var task2 = FDTask(title: "Done 2", notes: "", priority: .medium, isCompleted: true, isDeleted: false)

        project.tasks = [task1, task2]

        #expect(project.completionRate == 1.0)
    }
}

// MARK: - FDHabit Tests

@Suite("FDHabit Model Tests")
struct FDHabitTests {

    @Test("FDHabit initializes with correct properties")
    func habitInitialization() {
        let habit = FDHabit(
            name: "Exercise",
            emoji: "💪",
            frequency: .daily,
            preferredTime: .morning,
            currentStreak: 0,
            longestStreak: 0,
            isActive: true,
            logs: []
        )

        #expect(habit.name == "Exercise")
        #expect(habit.emoji == "💪")
        #expect(habit.frequency == .daily)
        #expect(habit.preferredTime == .morning)
        #expect(habit.currentStreak == 0)
        #expect(habit.longestStreak == 0)
        #expect(habit.isActive == true)
        #expect(habit.logs == [])
    }

    @Test("isDueToday is true for daily habits")
    func isDueTodayDaily() {
        let today = Date()
        let habit = FDHabit(
            name: "Daily",
            emoji: "📅",
            frequency: .daily,
            preferredTime: .morning,
            currentStreak: 0,
            longestStreak: 0,
            isActive: true,
            logs: []
        )

        #expect(habit.isDueToday == true)
    }

    @Test("isDueToday checks weekday frequency correctly")
    func isDueTodayWeekdays() {
        let today = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: today)

        let habit = FDHabit(
            name: "Weekday Habit",
            emoji: "📊",
            frequency: .weekdays,
            preferredTime: .morning,
            currentStreak: 0,
            longestStreak: 0,
            isActive: true,
            logs: []
        )

        // weekday: 1=Sunday, 2=Monday...7=Saturday
        let isWeekday = weekday >= 2 && weekday <= 6
        #expect(habit.isDueToday == isWeekday)
    }

    @Test("isDueToday checks weekend frequency correctly")
    func isDueTodayWeekends() {
        let today = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: today)

        let habit = FDHabit(
            name: "Weekend Habit",
            emoji: "🌳",
            frequency: .weekends,
            preferredTime: .evening,
            currentStreak: 0,
            longestStreak: 0,
            isActive: true,
            logs: []
        )

        let isWeekend = weekday == 1 || weekday == 7
        #expect(habit.isDueToday == isWeekend)
    }

    @Test("toggleToday completes habit and creates log entry")
    func toggleTodayCompletes() {
        var habit = FDHabit(
            name: "Toggle Test",
            emoji: "✅",
            frequency: .daily,
            preferredTime: .morning,
            currentStreak: 0,
            longestStreak: 0,
            isActive: true,
            logs: []
        )

        let before = habit.isCompletedToday
        let log = habit.toggleToday()

        #expect(before == false)
        #expect(habit.isCompletedToday == true)
        #expect(log != nil)
    }

    @Test("toggleToday uncompletes habit when already completed")
    func toggleTodayUncompletes() {
        var habit = FDHabit(
            name: "Toggle Test 2",
            emoji: "❌",
            frequency: .daily,
            preferredTime: .morning,
            currentStreak: 1,
            longestStreak: 5,
            isActive: true,
            logs: [FDHabitLog(date: Date(), completedAt: Date())]
        )

        habit.toggleToday()
        #expect(habit.isCompletedToday == false)
    }

    @Test("HabitFrequency cases are all present")
    func habitFrequencyCases() {
        let allFrequencies = HabitFrequency.allCases
        #expect(allFrequencies.contains(.daily))
        #expect(allFrequencies.contains(.weekdays))
        #expect(allFrequencies.contains(.weekends))
    }
}

// MARK: - NaturalLanguageParser Tests

@Suite("NaturalLanguageParser Tests")
struct NaturalLanguageParserTests {
    let parser = NaturalLanguageParser()

    @Test("Parse simple task title")
    func parseSimpleTitle() {
        let result = parser.parse("Buy groceries")

        #expect(result.title == "Buy groceries")
        #expect(result.priority == .medium)
        #expect(result.dueDate == nil)
        #expect(result.scheduledTime == nil)
        #expect(result.projectName == nil)
        #expect(result.labels == [])
        #expect(result.estimatedMinutes == nil)
    }

    @Test("Parse task with priority abbreviation p1")
    func parsePriorityP1() {
        let result = parser.parse("Review contract p1")

        #expect(result.title.contains("Review contract"))
        #expect(result.priority == .urgent)
    }

    @Test("Parse task with tomorrow date and time")
    func parseTomorrowAtTime() {
        let result = parser.parse("Meeting tomorrow at 2pm")

        #expect(result.title.contains("Meeting"))
        #expect(result.dueDate != nil)
        #expect(result.scheduledTime != nil)

        // Verify dueDate is tomorrow
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let dueDateComponent = calendar.component(.day, from: result.dueDate!)
        let tomorrowComponent = calendar.component(.day, from: tomorrow)
        #expect(dueDateComponent == tomorrowComponent)

        // Verify time is around 2pm (14:00)
        let hour = calendar.component(.hour, from: result.scheduledTime!)
        #expect(hour == 14)
    }

    @Test("Parse task with project and labels")
    func parseProjectAndLabels() {
        let result = parser.parse("Deploy app #Work @urgent 45m")

        #expect(result.title.contains("Deploy app"))
        #expect(result.projectName == "Work")
        #expect(result.labels.contains("urgent"))
        #expect(result.estimatedMinutes == 45)
    }

    @Test("Parse task with weekday recurrence")
    func parseWeekdayRecurrence() {
        let result = parser.parse("Stand up every weekday")

        #expect(result.title.contains("Stand up"))
        #expect(result.recurrenceRule != nil)

        // Should contain weekday pattern
        let rule = result.recurrenceRule ?? ""
        #expect(rule.contains("FREQ=WEEKLY"))
        #expect(rule.contains("BYDAY=MO,TU,WE,TH,FR"))
    }

    @Test("Parse task with due date on specific day")
    func parseDueFriday() {
        let result = parser.parse("Read chapter by Friday")

        #expect(result.title.contains("Read chapter"))
        #expect(result.dueDate != nil)

        // Due date should be on a Friday
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: result.dueDate!)
        #expect(weekday == 6) // Friday
    }

    @Test("Parse task with multiple hashtags for multiple projects")
    func parseMultipleHashtags() {
        let result = parser.parse("Organize #Personal #Home")

        #expect(result.title.contains("Organize"))
        // First hashtag becomes project
        #expect(result.projectName == "Personal")
    }

    @Test("Parse task with time but no explicit date")
    func parseTimeWithoutDate() {
        let result = parser.parse("Call doctor at 3pm")

        #expect(result.title.contains("Call doctor"))
        #expect(result.scheduledTime != nil)

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: result.scheduledTime!)
        #expect(hour == 15) // 3pm = 15:00
    }

    @Test("Parse empty string returns minimal result")
    func parseEmptyString() {
        let result = parser.parse("")

        #expect(result.title == "")
        #expect(result.priority == .medium)
    }
}

// MARK: - AIPlanner Tests

@Suite("AIPlanner Tests")
struct AIPlannerTests {
    let planner = AIPlanner()

    @Test("Generate plan with empty task list")
    func planEmptyTasks() {
        let result = planner.generatePlan(tasks: [], energyLevel: nil, existingEvents: [])

        #expect(result.suggestions.isEmpty)
        #expect(!result.summary.isEmpty)
    }

    @Test("Generate plan respects priority ordering")
    func planPriorityOrdering() {
        var urgentTask = FDTask(title: "Urgent", notes: "", priority: .urgent, isCompleted: false, isDeleted: false)
        var mediumTask = FDTask(title: "Medium", notes: "", priority: .medium, isCompleted: false, isDeleted: false)
        var lowTask = FDTask(title: "Low", notes: "", priority: .none, isCompleted: false, isDeleted: false)

        let tasks = [mediumTask, lowTask, urgentTask] // Out of order
        let result = planner.generatePlan(tasks: tasks, energyLevel: .high, existingEvents: [])

        // Urgent task should be suggested first
        if !result.suggestions.isEmpty {
            #expect(result.suggestions[0].task.priority == .urgent)
        }
    }

    @Test("Plan with high energy includes more tasks")
    func planHighEnergyMoreTasks() {
        var tasks: [FDTask] = []
        for i in 1...5 {
            var task = FDTask(title: "Task \(i)", notes: "", priority: .medium, isCompleted: false, isDeleted: false)
            tasks.append(task)
        }

        let lowEnergyResult = planner.generatePlan(tasks: tasks, energyLevel: .low, existingEvents: [])
        let highEnergyResult = planner.generatePlan(tasks: tasks, energyLevel: .high, existingEvents: [])

        // High energy should suggest more tasks
        #expect(highEnergyResult.suggestions.count >= lowEnergyResult.suggestions.count)
    }

    @Test("Plan avoids overlapping with existing events")
    func planAvoidsConflicts() {
        var task = FDTask(title: "Schedule Me", notes: "", priority: .high, isCompleted: false, isDeleted: false)

        let now = Date()
        let oneHourFromNow = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        let twoHoursFromNow = Calendar.current.date(byAdding: .hour, value: 2, to: now)!

        let existingEvents = [(start: now, end: oneHourFromNow)]

        let result = planner.generatePlan(tasks: [task], energyLevel: nil, existingEvents: existingEvents)

        // Suggestions should not overlap with existing event (if any suggestions made)
        for suggestion in result.suggestions {
            if let suggestedTime = suggestion.suggestedTime {
                #expect(suggestedTime >= oneHourFromNow || suggestedTime < now)
            }
        }
    }

    @Test("Plan includes tips for planning")
    func planIncludesTips() {
        var task = FDTask(title: "Test", notes: "", priority: .high, isCompleted: false, isDeleted: false)
        let result = planner.generatePlan(tasks: [task], energyLevel: .medium, existingEvents: [])

        #expect(!result.tips.isEmpty)
        #expect(result.tips.count > 0)
    }

    @Test("Plan summary is non-empty")
    func planSummaryExists() {
        var task = FDTask(title: "Test", notes: "", priority: .medium, isCompleted: false, isDeleted: false)
        let result = planner.generatePlan(tasks: [task], energyLevel: nil, existingEvents: [])

        #expect(!result.summary.isEmpty)
    }
}

// MARK: - KeychainHelper Tests

@Suite("KeychainHelper Tests")
struct KeychainHelperTests {
    let keychainHelper = KeychainHelper()
    let testKey = "test_key_\(UUID().uuidString)"

    @Test("Save and retrieve string from keychain")
    func saveAndRetrieveString() {
        let testValue = "SecureTestValue123"

        let saveSuccess = keychainHelper.save(testValue, forKey: testKey)
        #expect(saveSuccess == true)

        let retrieved = keychainHelper.retrieve(forKey: testKey)
        #expect(retrieved == testValue)
    }

    @Test("Retrieve non-existent key returns nil")
    func retrieveNonExistentKey() {
        let nonExistentKey = "non_existent_key_\(UUID().uuidString)"
        let retrieved = keychainHelper.retrieve(forKey: nonExistentKey)

        #expect(retrieved == nil)
    }

    @Test("Delete removes item from keychain")
    func deleteFromKeychain() {
        let testValue = "DeleteMe"
        keychainHelper.save(testValue, forKey: testKey)

        let deleteSuccess = keychainHelper.delete(forKey: testKey)
        #expect(deleteSuccess == true)

        let retrieved = keychainHelper.retrieve(forKey: testKey)
        #expect(retrieved == nil)
    }

    @Test("Update existing keychain value")
    func updateKeychainValue() {
        let initialValue = "Initial"
        let updatedValue = "Updated"

        keychainHelper.save(initialValue, forKey: testKey)
        let firstRetrieve = keychainHelper.retrieve(forKey: testKey)
        #expect(firstRetrieve == initialValue)

        keychainHelper.save(updatedValue, forKey: testKey)
        let secondRetrieve = keychainHelper.retrieve(forKey: testKey)
        #expect(secondRetrieve == updatedValue)
    }

    @Test("Save empty string works correctly")
    func saveEmptyString() {
        let emptyString = ""
        let saveSuccess = keychainHelper.save(emptyString, forKey: testKey)
        #expect(saveSuccess == true)

        let retrieved = keychainHelper.retrieve(forKey: testKey)
        #expect(retrieved == emptyString)
    }

    @Test("Multiple keys can be stored independently")
    func multipleKeysIndependent() {
        let key1 = "key1_\(UUID().uuidString)"
        let key2 = "key2_\(UUID().uuidString)"
        let value1 = "Value1"
        let value2 = "Value2"

        keychainHelper.save(value1, forKey: key1)
        keychainHelper.save(value2, forKey: key2)

        let retrieved1 = keychainHelper.retrieve(forKey: key1)
        let retrieved2 = keychainHelper.retrieve(forKey: key2)

        #expect(retrieved1 == value1)
        #expect(retrieved2 == value2)

        keychainHelper.delete(forKey: key1)
        keychainHelper.delete(forKey: key2)
    }
}

// MARK: - Integration Tests

@Suite("Integration Tests")
struct IntegrationTests {

    @Test("Task project relationship consistency")
    func taskProjectRelationship() {
        var project = FDProject(name: "Integration Test", colorHex: "#123456", tasks: [], isArchived: false, isFavorite: false)
        var task = FDTask(title: "Integrated Task", notes: "", priority: .high, isCompleted: false, isDeleted: false)
        task.project = project
        project.tasks.append(task)

        #expect(task.project?.name == "Integration Test")
        #expect(project.tasks.contains { $0.title == "Integrated Task" })
    }

    @Test("Habit toggle updates isCompletedToday correctly")
    func habitToggleCompletionStatus() {
        var habit = FDHabit(
            name: "Integration Habit",
            emoji: "🎯",
            frequency: .daily,
            preferredTime: .afternoon,
            currentStreak: 0,
            longestStreak: 0,
            isActive: true,
            logs: []
        )

        #expect(habit.isCompletedToday == false)

        _ = habit.toggleToday()
        #expect(habit.isCompletedToday == true)

        _ = habit.toggleToday()
        #expect(habit.isCompletedToday == false)
    }

    @Test("Natural language parser output works with AIPlanner")
    func parserOutputToPlanner() {
        let parser = NaturalLanguageParser()
        let planner = AIPlanner()

        let parsed = parser.parse("Complete report p1 tomorrow at 10am #Work")

        // Create task from parsed result
        var task = FDTask(
            title: parsed.title,
            notes: "",
            priority: parsed.priority,
            isCompleted: false,
            isDeleted: false
        )
        task.dueDate = parsed.dueDate
        task.scheduledTime = parsed.scheduledTime

        // Generate plan
        let plan = planner.generatePlan(tasks: [task], energyLevel: .high, existingEvents: [])

        #expect(!plan.suggestions.isEmpty || !plan.summary.isEmpty)
    }
}
