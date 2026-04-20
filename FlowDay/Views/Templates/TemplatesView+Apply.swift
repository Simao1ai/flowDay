// TemplatesView+Apply.swift
// FlowDay
//
// "Use this template" → project + starter tasks. The per-template starter
// task lists live here too, kept as a single switch so adding a new template
// is one edit in the catalog and one case here.

import SwiftUI
import SwiftData

extension TemplatesView {

    func applyTemplate(_ template: TemplateItem) {
        Haptics.success()
        let colorHex = template.color.toHex() ?? "#D4713B"
        let project = FDProject(name: template.name, colorHex: colorHex, iconName: template.icon)
        modelContext.insert(project)

        let tasks = templateTasks(for: template)
        for (index, taskTitle) in tasks.enumerated() {
            let task = FDTask(
                title: taskTitle,
                priority: index == 0 ? .high : .medium,
                project: project
            )
            modelContext.insert(task)
        }

        try? modelContext.save()
        appliedTemplateName = template.name
        showTemplateApplied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }

    func templateTasks(for template: TemplateItem) -> [String] {
        switch template.name {

        // Featured
        case "Energy-Aware Day":
            return ["Log your energy level for morning, afternoon & evening", "Identify your peak energy window this week", "Schedule your hardest task during peak energy", "Move low-effort tasks to your energy dip hours", "Review & rate how the energy-matched day felt"]
        case "AI Task Breakdown":
            return ["Define one big goal you want to accomplish", "Let AI break it into 5-7 subtasks", "Assign priorities and deadlines to each subtask", "Complete the first subtask today", "Review progress and adjust the plan"]
        case "Weekly Review Ritual":
            return ["Review all completed tasks from this week", "Move unfinished tasks to next week or archive them", "Celebrate 3 wins from the past week", "Set your top 3 priorities for next week", "Clear your inbox and process all loose items"]
        case "Morning Power Hour":
            return ["Review today's schedule and top 3 priorities", "Complete your most important task first", "Process and respond to urgent messages only", "Plan your time blocks for the rest of the day", "Set one intention for how you want to feel today"]
        case "Focus Sprint":
            return ["Choose one high-priority task to deep work on", "Set a 45-minute focus timer with no distractions", "Take a 10-minute break — walk or stretch", "Do a second 45-minute focus session", "Log what you accomplished and how it felt"]

        // Real Estate
        case "Open House Prep":
            return ["Stage property & declutter every room", "Print marketing materials & sign-in sheets", "Set up signage and directional signs", "Prepare refreshments & background music", "Follow up with all attendees within 24 hours"]
        case "Listing Launch":
            return ["Schedule professional photography", "Write compelling listing description", "Submit to MLS & syndicate portals", "Create social media campaign", "Schedule first open house"]
        case "Buyer Pipeline":
            return ["Initial consultation & needs assessment", "Set up automated property search alerts", "Schedule property showings for the week", "Pull comparable sales for top picks", "Prepare & submit offer with cover letter"]
        case "Transaction Coordinator":
            return ["Collect signed purchase agreement", "Order title search & home inspection", "Coordinate with lender on financing timeline", "Review all disclosures & compliance documents", "Schedule closing & final walkthrough"]

        // Freelance & Agency
        case "Client Onboarding":
            return ["Send welcome packet & signed contract", "Schedule 30-min kickoff call", "Set up shared project workspace (Notion, Drive, etc.)", "Define communication cadence & channels", "Deliver project timeline with milestones"]
        case "Project Sprint":
            return ["Define sprint goal & deliverables", "Break deliverables into daily tasks", "Set up progress check-in for mid-sprint", "Complete all deliverables before sprint end", "Send client update with completed work"]
        case "Invoice & Follow-up":
            return ["Generate invoice from completed milestones", "Send invoice with payment instructions", "Set 7-day payment reminder", "Follow up on overdue invoices", "Log payment received & update books"]

        // Students
        case "Semester Planner":
            return ["Add all class times to your calendar", "Map out every assignment due date from syllabi", "Block weekly study sessions for each course", "Set up a note-taking system per class", "Schedule monthly check-ins on grade progress"]
        case "Research Paper":
            return ["Choose topic & get advisor approval", "Gather 10+ sources and annotate key findings", "Write thesis statement & outline", "Draft body paragraphs section by section", "Revise, format citations, and proofread"]
        case "Exam Prep Sprint":
            return ["Gather all study materials & past exams", "Create condensed review sheets per topic", "Practice with timed mock exams", "Review mistakes and weak areas", "Do a light review the day before — no cramming"]

        // Healthcare
        case "Patient Follow-up":
            return ["Review patient chart & recent visit notes", "Call patient to check on recovery progress", "Update care plan based on follow-up", "Schedule next appointment if needed", "Document follow-up notes in patient record"]
        case "Shift Handoff":
            return ["Review current patient statuses", "Note any critical changes or new orders", "Document pending tasks for incoming shift", "Brief incoming staff on priority patients", "Confirm handoff is complete with sign-off"]
        case "Continuing Education":
            return ["Check CE credit requirements for this cycle", "Research available courses & conferences", "Register for at least one course", "Complete coursework and take assessment", "Submit proof of completion for credits"]

        // Construction & Trades
        case "Job Site Checklist":
            return ["Complete morning safety walkthrough", "Verify all materials are on-site", "Check permits & inspection schedule", "Take progress photos and document work", "Update project timeline & flag delays"]
        case "Estimate & Bid":
            return ["Visit site and take measurements", "List all materials, labor & equipment needed", "Get supplier quotes for materials", "Calculate total with markup and contingency", "Submit professional proposal to client"]

        // Content Creators
        case "Content Calendar":
            return ["Brainstorm 10 content ideas for the month", "Assign each idea a platform and publish date", "Create or source visuals for each post", "Write captions and hashtag sets", "Schedule all posts using your publishing tool"]
        case "Video Production":
            return ["Write script & create shot list", "Set up filming location & lighting", "Record all footage and B-roll", "Edit video with transitions, music & captions", "Upload, write description & schedule publish"]
        case "Brand Collaboration":
            return ["Research brand & align on deliverables", "Draft proposal with rates & timeline", "Create content per agreed brief", "Submit for brand review & approval", "Publish and send performance report"]

        // Small Business
        case "Business Launch Checklist":
            return ["Register business name & get EIN/licenses", "Set up business bank account", "Build simple website or landing page", "Create social media profiles", "Launch with an announcement post & email"]
        case "Inventory Management":
            return ["Audit current stock levels", "Identify low-stock and overstock items", "Place reorder for essential items", "Update inventory tracking system", "Set reorder alerts for top sellers"]
        case "Customer Feedback Loop":
            return ["Send post-purchase satisfaction survey", "Collect and categorize all feedback", "Identify top 3 recurring complaints", "Create action plan for each issue", "Follow up with customers on changes made"]

        // Sales & Marketing
        case "Product Launch":
            return ["Finalize launch date & key messaging", "Create landing page & marketing assets", "Set up email drip campaign", "Schedule social media launch sequence", "Monitor launch metrics & respond to feedback"]
        case "Lead Nurture Sequence":
            return ["Segment leads by interest & stage", "Write 5-email nurture sequence", "Set up automated send schedule", "Track open rates & click-throughs", "Follow up personally with hot leads"]
        case "Campaign Tracker":
            return ["Define campaign goal & target KPIs", "Launch ads across chosen channels", "Monitor daily spend & performance", "A/B test creative and copy variations", "Compile final report with ROI analysis"]

        // Software & Engineering
        case "Sprint Planning":
            return ["Review backlog & prioritize by impact", "Estimate story points for top items", "Assign tasks to team members", "Set sprint goal & define done criteria", "Schedule daily standup cadence"]
        case "Bug Triage":
            return ["Collect all new bug reports", "Reproduce and confirm each bug", "Assign severity: critical, high, medium, low", "Assign bugs to owners with deadlines", "Verify fixes and close resolved bugs"]
        case "Feature Rollout":
            return ["Write feature spec & get stakeholder sign-off", "Implement feature with tests", "Deploy to staging & run QA", "Create feature flag for gradual rollout", "Monitor metrics post-launch & iterate"]

        // Legal & Compliance
        case "Contract Review":
            return ["Read full contract and flag key clauses", "Check for liability & indemnification terms", "Verify payment terms & deadlines", "Note any non-compete or exclusivity clauses", "Send summary with recommended changes"]
        case "Compliance Audit":
            return ["Gather all required documentation", "Review against current regulatory requirements", "Identify gaps & non-compliance risks", "Create remediation plan with deadlines", "Submit audit report to stakeholders"]
        case "Case File Setup":
            return ["Open new case file with client details", "Collect all relevant documents & evidence", "Set key dates: filings, hearings, deadlines", "Draft initial strategy memo", "Schedule client update meeting"]

        // Finance & Accounting
        case "Monthly Close":
            return ["Reconcile all bank & credit card accounts", "Review and categorize pending transactions", "Post adjusting journal entries", "Generate P&L and balance sheet", "Send financial summary to stakeholders"]
        case "Tax Prep Checklist":
            return ["Gather all income documents (W-2s, 1099s)", "Compile deduction receipts & records", "Review last year's return for carryovers", "Complete and review tax forms", "File return and set up estimated payments"]
        case "Budget Planning":
            return ["Review last period's actuals vs. budget", "Identify areas of overspend & underspend", "Set targets for each category next period", "Build budget spreadsheet with projections", "Get approval & share with team"]

        // Events & Planning
        case "Event Planning":
            return ["Define event goals, theme & date", "Book venue and key vendors", "Create guest list & send invitations", "Plan event run-of-show timeline", "Post-event: send thank-yous & gather feedback"]
        case "Conference Prep":
            return ["Register & book travel and hotel", "Review speaker lineup & plan your schedule", "Prepare business cards & elevator pitch", "Set networking goals (meet 5 new people)", "Post-conference: follow up with new contacts"]
        case "Party Planner":
            return ["Set date, theme & guest count", "Book venue or prep hosting space", "Order food, drinks & decorations", "Create playlist & plan activities", "Send reminders 2 days before"]

        // Nonprofit & Community
        case "Fundraising Campaign":
            return ["Define fundraising goal & timeline", "Create campaign page & donation link", "Draft outreach emails & social posts", "Reach out to major donors personally", "Send thank-you notes & share impact report"]
        case "Volunteer Coordination":
            return ["Post volunteer opportunity & requirements", "Screen and confirm volunteers", "Create shift schedule & assignments", "Send briefing with logistics & expectations", "Collect feedback & thank volunteers"]
        case "Grant Application":
            return ["Research eligible grants & deadlines", "Gather required documents & data", "Write project narrative & budget justification", "Get internal review & sign-offs", "Submit application before deadline"]

        // Education & Teaching
        case "Lesson Plan Builder":
            return ["Define learning objectives for the unit", "Outline activities, materials & timing", "Create handouts or digital resources", "Plan assessment (quiz, project, discussion)", "Reflect on what worked after delivery"]
        case "Parent-Teacher Prep":
            return ["Review each student's progress & grades", "Note specific strengths & areas for growth", "Prepare talking points & examples", "Set up meeting schedule & send reminders", "Document action items from each meeting"]
        case "Classroom Setup":
            return ["Arrange desks & seating chart", "Set up bulletin boards & learning stations", "Organize supplies & label storage areas", "Test all tech (projector, tablets, Wi-Fi)", "Prepare first-day welcome activity"]

        // Life & Personal
        case "Home Renovation":
            return ["Choose room to start & set budget", "Research contractors & get 3 quotes", "Order materials & set delivery dates", "Supervise work & do daily progress check", "Final walkthrough & punch list"]
        case "Wedding Planning":
            return ["Set budget & create guest list", "Book venue & caterer", "Choose photographer, florist & DJ", "Send invitations & track RSVPs", "Create day-of timeline & assign roles"]
        case "Move & Relocate":
            return ["Declutter & decide what to keep, donate, toss", "Book movers or reserve a truck", "Pack room by room with labeled boxes", "Transfer utilities, mail & subscriptions", "Unpack essentials first & settle in"]
        case "Travel Planner":
            return ["Choose destination & set travel dates", "Book flights & accommodation", "Plan daily itinerary with key activities", "Create packing list & check documents", "Download offline maps & confirm reservations"]
        case "Fitness Journey":
            return ["Set specific fitness goal (weight, strength, endurance)", "Create weekly workout schedule", "Meal prep for the week (protein, veggies, carbs)", "Track workouts & log progress photos", "Weekly check-in: adjust plan based on results"]
        case "Side Hustle Launch":
            return ["Validate your idea with 5 potential customers", "Set up a simple landing page or storefront", "Create your first product or service offering", "Post your launch on social media & tell friends", "Get your first paying customer this week"]
        case "Digital Detox Week":
            return ["Set screen time limits on all devices", "Delete or log out of social media apps", "Replace phone time with a book or hobby", "Go for a daily 30-minute walk without your phone", "Journal each evening about how the day felt"]
        case "Meal Prep Master":
            return ["Plan 5 dinners + lunches for the week", "Write grocery list organized by store section", "Shop & buy everything in one trip", "Batch cook proteins, grains & chop veggies", "Portion into containers & label with dates"]

        // Productivity Methods
        case "Getting Things Done":
            return ["Do a full brain dump — capture everything on your mind", "Process each item: is it actionable? Delete, defer, or do", "Organize into projects, next actions & waiting-for lists", "Review all lists weekly and update", "Trust the system — stop holding tasks in your head"]
        case "Time Blocking":
            return ["List your top 3 priorities for tomorrow", "Block 90-minute deep work sessions on your calendar", "Assign specific tasks to each time block", "Add buffer blocks for email & unexpected tasks", "Review at end of day: did you follow the blocks?"]
        case "Eat The Frog":
            return ["Identify your hardest or most dreaded task", "Do it first thing in the morning — no excuses", "Set a timer for 25 minutes and just start", "Reward yourself after completing it", "Pick tomorrow's frog before leaving work today"]
        case "Eisenhower Matrix":
            return ["List all your current tasks and to-dos", "Sort each into: Urgent+Important, Important, Urgent, Neither", "Do Urgent+Important tasks immediately", "Schedule Important tasks for this week", "Delegate or delete everything else"]
        case "Kanban":
            return ["Create three columns: To Do, In Progress, Done", "Add all current tasks to the To Do column", "Move only 3 tasks to In Progress at a time", "Move tasks to Done as you complete them", "Review the board daily and add new tasks"]
        case "The Pomodoro Technique":
            return ["Choose one task to focus on", "Set a 25-minute timer and work with zero distractions", "Take a 5-minute break when the timer rings", "After 4 pomodoros, take a 15-30 minute break", "Log how many pomodoros each task took"]
        case "The 1-3-5 Rule":
            return ["Pick 1 big task that will move the needle today", "Pick 3 medium tasks that support your goals", "Pick 5 small tasks (emails, errands, quick fixes)", "Work through them in order: big → medium → small", "End of day: celebrate what you finished"]
        case "Energy Mapping":
            return ["Track your energy levels every 2 hours for 3 days", "Identify your consistent high & low energy windows", "Schedule deep work during your peak energy time", "Move meetings & admin to your low energy slots", "Adjust weekly as your patterns shift"]

        default:
            return ["Define your goal clearly", "Break it into 5 actionable steps", "Set a deadline for each step", "Track progress daily", "Review & celebrate your wins"]
        }
    }
}
