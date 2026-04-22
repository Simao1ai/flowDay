// PremiumTemplateLibrary.swift
// FlowDay
//
// The 5 flagship templates in the rich PremiumTemplate format.
// Each template has sections/phases, per-task notes, relative due dates,
// recurring flags, subtasks, and a how-to-use intro.

import Foundation

enum PremiumTemplateLibrary {

    static let all: [PremiumTemplate] = [
        projectTracker,
        weeklyReviewRitual,
        productLaunch,
        homeRenovation,
        morningPowerHour,
    ]

    static func find(named name: String) -> PremiumTemplate? {
        all.first { $0.name == name }
    }

    // MARK: - Project Tracker

    static let projectTracker = PremiumTemplate(
        id: "premium-project-tracker",
        name: "Project Tracker",
        description: "End-to-end project management from kickoff to closeout with milestones, weekly check-ins, and a structured retrospective.",
        icon: "chart.gantt",
        colorHex: "#4F8EF7",
        category: "featured",
        howToUse: """
        Apply this template at the start of any project. Spend real time in the Planning phase before writing a single line of code or sending a single email — decisions made here save 3x their effort later. The Weekly Check-in task recurs automatically to keep momentum visible. Use the Close-out section to capture learnings before archiving so the next project benefits from this one.
        """,
        sections: [
            .init(
                id: "pt-planning",
                title: "Project Setup",
                emoji: "🎯",
                description: "Define scope, stakeholders, and success criteria before execution begins.",
                tasks: [
                    .init(
                        title: "Write the project brief",
                        notes: "Define: what are we building, why now, who is it for, and what does success look like? Keep it to one page. If you can't explain it in one page, the scope isn't clear yet.",
                        relativeDueDays: 0,
                        priority: 1,
                        estimatedMinutes: 60,
                        labels: ["setup"]
                    ),
                    .init(
                        title: "Identify stakeholders and decision-makers",
                        notes: "Who needs to be informed? Who has veto power? Who is your day-to-day contact? Write down names, not just roles.",
                        relativeDueDays: 0,
                        priority: 2,
                        estimatedMinutes: 30,
                        labels: ["setup"]
                    ),
                    .init(
                        title: "Set milestones and target dates",
                        notes: "Work backwards from the deadline. Define 3-5 major milestones with clear completion criteria — not just 'done,' but 'done means X.'",
                        relativeDueDays: 1,
                        priority: 1,
                        estimatedMinutes: 45,
                        subtasks: [
                            .init(title: "Milestone 1: kickoff & brief signed off"),
                            .init(title: "Milestone 2: first draft / prototype"),
                            .init(title: "Milestone 3: review & revisions complete"),
                            .init(title: "Milestone 4: final delivery"),
                        ],
                        labels: ["setup", "planning"]
                    ),
                    .init(
                        title: "Set up project workspace and communication channel",
                        notes: "Create shared folder structure, docs, and communication channel. Agree on one source of truth — not two.",
                        relativeDueDays: 1,
                        priority: 3,
                        estimatedMinutes: 30,
                        labels: ["setup"]
                    ),
                ]
            ),
            .init(
                id: "pt-execution",
                title: "Execution",
                emoji: "🔨",
                description: "Weekly rituals to keep the project on track and risks visible.",
                tasks: [
                    .init(
                        title: "Weekly project check-in",
                        notes: "Three questions: What was completed? What's blocked? Is the timeline holding? Update stakeholders in 3 sentences — no lengthy status reports.",
                        relativeDueDays: 7,
                        priority: 2,
                        estimatedMinutes: 30,
                        isRecurring: true,
                        recurringInterval: .weekly,
                        labels: ["check-in", "recurring"]
                    ),
                    .init(
                        title: "Address top blocker",
                        notes: "Every project has at least one active blocker. Name it explicitly, assign an owner, and set a deadline to resolve it. Unnamed blockers don't get resolved.",
                        relativeDueDays: 7,
                        priority: 1,
                        estimatedMinutes: 45,
                        labels: ["blocker"]
                    ),
                    .init(
                        title: "Mid-project stakeholder update",
                        notes: "30-minute sync at the halfway point. Share what's done, what's ahead, and any scope changes. Surprises at the end cost more than surprises in the middle.",
                        relativeDueDays: 14,
                        priority: 2,
                        estimatedMinutes: 30,
                        labels: ["stakeholder"]
                    ),
                ]
            ),
            .init(
                id: "pt-closeout",
                title: "Close-out",
                emoji: "🏁",
                description: "Document learnings and ensure a clean handoff before archiving.",
                tasks: [
                    .init(
                        title: "Final deliverable review against success criteria",
                        notes: "Pull up the project brief from week one. Run through every success criterion you defined. Document any gaps — honestly.",
                        relativeDueDays: 28,
                        priority: 1,
                        estimatedMinutes: 60,
                        labels: ["review"]
                    ),
                    .init(
                        title: "Write retrospective",
                        notes: "3 things that worked well. 3 things to do differently next time. 1 systemic improvement the team should adopt. Keep it under one page.",
                        relativeDueDays: 29,
                        priority: 2,
                        estimatedMinutes: 45,
                        labels: ["review"]
                    ),
                    .init(
                        title: "Archive project and celebrate the win",
                        notes: "Organize all files, close out tasks, and take a moment to acknowledge what the team built. Momentum compounds when wins are recognized.",
                        relativeDueDays: 30,
                        priority: 3,
                        estimatedMinutes: 20,
                        labels: ["admin"]
                    ),
                ]
            ),
        ]
    )

    // MARK: - Weekly Review Ritual

    static let weeklyReviewRitual = PremiumTemplate(
        id: "premium-weekly-review",
        name: "Weekly Review Ritual",
        description: "A structured 60-minute ritual to close out the past week, capture loose ends, and build a confident plan for the week ahead.",
        icon: "calendar.badge.checkmark",
        colorHex: "#4A90D9",
        category: "featured",
        howToUse: """
        Block 60 minutes on Friday afternoon or Sunday evening. Work through all three sections in order: Review first, then Reflect, then Plan. The Reflect section is the most skipped and the most valuable — don't rush it. Over time this log becomes one of the most useful documents you own.
        """,
        sections: [
            .init(
                id: "wr-review",
                title: "Review",
                emoji: "🔍",
                description: "Close the loop on everything from last week — completed, missed, and lingering.",
                tasks: [
                    .init(
                        title: "Review all completed tasks from this week",
                        notes: "Scan through completions. Is there anything you need to follow up on, document, or communicate to someone? Mark it now rather than letting it slip.",
                        relativeDueDays: 0,
                        priority: 2,
                        estimatedMinutes: 10,
                        isRecurring: true,
                        recurringInterval: .weekly,
                        labels: ["review", "weekly"]
                    ),
                    .init(
                        title: "Process all unfinished tasks",
                        notes: "For each uncompleted task: reschedule (pick a real date), delegate, or delete. Zero tolerance for zombie tasks that keep rolling forward week after week.",
                        relativeDueDays: 0,
                        priority: 1,
                        estimatedMinutes: 15,
                        isRecurring: true,
                        recurringInterval: .weekly,
                        labels: ["review", "weekly"]
                    ),
                    .init(
                        title: "Clear inbox and capture loose items",
                        notes: "Email, notes, messages, sticky notes, random thoughts — capture anything that hasn't been added to your task system yet. Empty the queue.",
                        relativeDueDays: 0,
                        priority: 2,
                        estimatedMinutes: 10,
                        isRecurring: true,
                        recurringInterval: .weekly,
                        labels: ["inbox", "weekly"]
                    ),
                ]
            ),
            .init(
                id: "wr-reflect",
                title: "Reflect",
                emoji: "🧠",
                description: "The part most people skip — and the part that compounds most over time.",
                tasks: [
                    .init(
                        title: "Name your 3 wins this week",
                        notes: "Not just completed tasks — real wins. Progress on something hard. A conversation that went well. A decision you made under uncertainty. Write them down.",
                        relativeDueDays: 0,
                        priority: 2,
                        estimatedMinutes: 5,
                        isRecurring: true,
                        recurringInterval: .weekly,
                        subtasks: [
                            .init(title: "Win 1"),
                            .init(title: "Win 2"),
                            .init(title: "Win 3"),
                        ],
                        labels: ["reflect", "weekly"]
                    ),
                    .init(
                        title: "Identify what drained your energy this week",
                        notes: "Which tasks felt like a grind? Which meetings were a waste? What are you tolerating that you shouldn't be? One honest sentence is enough.",
                        relativeDueDays: 0,
                        priority: 3,
                        estimatedMinutes: 5,
                        isRecurring: true,
                        recurringInterval: .weekly,
                        labels: ["reflect", "weekly"]
                    ),
                    .init(
                        title: "Rate your week (1–10) and write one sentence why",
                        notes: "Gut check. Over time this log becomes a valuable signal about what kinds of weeks feel most alive to you — and which patterns to repeat or avoid.",
                        relativeDueDays: 0,
                        priority: 3,
                        estimatedMinutes: 3,
                        isRecurring: true,
                        recurringInterval: .weekly,
                        labels: ["reflect", "weekly"]
                    ),
                ]
            ),
            .init(
                id: "wr-plan",
                title: "Plan Ahead",
                emoji: "📅",
                description: "Set up next week for success before you close your laptop.",
                tasks: [
                    .init(
                        title: "Set your top 3 priorities for next week",
                        notes: "Write these as outcomes, not tasks. 'Ship the onboarding flow' not 'work on onboarding.' If next week went sideways and you only hit these 3, was it a good week?",
                        relativeDueDays: 0,
                        priority: 1,
                        estimatedMinutes: 10,
                        isRecurring: true,
                        recurringInterval: .weekly,
                        subtasks: [
                            .init(title: "Priority 1 — the one that matters most"),
                            .init(title: "Priority 2"),
                            .init(title: "Priority 3"),
                        ],
                        labels: ["planning", "weekly"]
                    ),
                    .init(
                        title: "Block deep work sessions in your calendar",
                        notes: "Block 2–3 × 90-minute deep work slots NOW, before meetings fill them. Morning slots are almost always better than afternoon ones.",
                        relativeDueDays: 0,
                        priority: 2,
                        estimatedMinutes: 10,
                        isRecurring: true,
                        recurringInterval: .weekly,
                        labels: ["planning", "calendar", "weekly"]
                    ),
                    .init(
                        title: "Scan upcoming deadlines and commitments",
                        notes: "Look 2 weeks ahead. Any deadlines sneaking up? Any prep needed for upcoming meetings or presentations? Flag them now.",
                        relativeDueDays: 0,
                        priority: 2,
                        estimatedMinutes: 5,
                        isRecurring: true,
                        recurringInterval: .weekly,
                        labels: ["planning", "weekly"]
                    ),
                ]
            ),
        ]
    )

    // MARK: - Product Launch

    static let productLaunch = PremiumTemplate(
        id: "premium-product-launch",
        name: "Product Launch",
        description: "A three-phase launch playbook covering messaging validation, asset creation, distribution, and post-launch iteration — for software, physical products, or services.",
        icon: "rocket",
        colorHex: "#E8574A",
        category: "Sales & Marketing",
        howToUse: """
        Apply this template 4–6 weeks before your target launch date. The relativeDueDays count from when you apply the template — adjust dates once you've set your launch day. The Post-Launch phase is just as important as the launch itself; schedule it now so you don't skip it in the post-launch chaos.
        """,
        sections: [
            .init(
                id: "pl-prelaunch",
                title: "Pre-Launch",
                emoji: "🏗️",
                description: "Build the infrastructure and narrative before making any noise.",
                tasks: [
                    .init(
                        title: "Finalize launch date and lock the scope",
                        notes: "Write down exactly what is and isn't included in v1. Anything not on the list is a v2 feature. Date slippage is almost always scope creep in disguise.",
                        relativeDueDays: 0,
                        priority: 1,
                        estimatedMinutes: 60,
                        labels: ["strategy"]
                    ),
                    .init(
                        title: "Write and validate core messaging",
                        notes: "Answer: Who is this for? What problem does it solve? Why now? Why us? Get feedback from 3 actual potential customers before writing any copy.",
                        relativeDueDays: 2,
                        priority: 1,
                        estimatedMinutes: 120,
                        subtasks: [
                            .init(title: "Draft one-sentence value proposition"),
                            .init(title: "Write 3-paragraph elevator pitch"),
                            .init(title: "Test with 3 target customers and revise"),
                            .init(title: "Finalize headline and tagline"),
                        ],
                        labels: ["messaging", "strategy"]
                    ),
                    .init(
                        title: "Build landing page",
                        notes: "Simple is better than impressive. Headline, 3 key benefits, social proof, one CTA. Launch with this, iterate later. Don't wait for the 'perfect' site.",
                        relativeDueDays: 7,
                        priority: 1,
                        estimatedMinutes: 180,
                        labels: ["marketing", "website"]
                    ),
                    .init(
                        title: "Create launch email sequence",
                        notes: "At minimum: pre-launch teaser, launch day announcement, 3-day follow-up. Write all three before you send the first one.",
                        relativeDueDays: 10,
                        priority: 2,
                        estimatedMinutes: 120,
                        subtasks: [
                            .init(title: "Write pre-launch teaser email"),
                            .init(title: "Write launch day announcement"),
                            .init(title: "Write 3-day follow-up"),
                            .init(title: "Set up automation in email tool"),
                        ],
                        labels: ["marketing", "email"]
                    ),
                    .init(
                        title: "Prepare social media launch assets",
                        notes: "3–5 posts covering: what it is, who it's for, one specific use case, social proof, and a direct CTA. Write captions for all posts before launch day.",
                        relativeDueDays: 14,
                        priority: 2,
                        estimatedMinutes: 90,
                        labels: ["marketing", "social"]
                    ),
                    .init(
                        title: "Set up tracking and analytics",
                        notes: "At minimum: landing page visits, email signups, conversion rate, and revenue. You can't improve what you can't measure.",
                        relativeDueDays: 14,
                        priority: 2,
                        estimatedMinutes: 60,
                        labels: ["analytics"]
                    ),
                ]
            ),
            .init(
                id: "pl-launch",
                title: "Launch Day",
                emoji: "🚀",
                description: "Execute the plan. Your only job today is distribution and responsiveness.",
                tasks: [
                    .init(
                        title: "Send launch announcement to email list",
                        notes: "Send at 9–10am in your primary market's timezone. DO NOT overthink this at the last minute — you wrote the email already. Just press send.",
                        relativeDueDays: 21,
                        priority: 1,
                        estimatedMinutes: 15,
                        labels: ["launch", "email"]
                    ),
                    .init(
                        title: "Post across all social channels",
                        notes: "Post your pre-written content. Engage with every comment in the first 2 hours — the algorithm rewards early engagement velocity.",
                        relativeDueDays: 21,
                        priority: 1,
                        estimatedMinutes: 30,
                        labels: ["launch", "social"]
                    ),
                    .init(
                        title: "Reach out personally to top 10 potential customers",
                        notes: "'Hey [name], I launched [thing] today and immediately thought of your [specific situation].' Personalized DMs, not a broadcast. Ten real messages beat 1,000 generic ones.",
                        relativeDueDays: 21,
                        priority: 1,
                        estimatedMinutes: 60,
                        subtasks: [
                            .init(title: "Contact 1"),
                            .init(title: "Contact 2"),
                            .init(title: "Contact 3"),
                            .init(title: "Contact 4"),
                            .init(title: "Contact 5"),
                            .init(title: "Contacts 6–10"),
                        ],
                        labels: ["launch", "outreach"]
                    ),
                    .init(
                        title: "Monitor and respond to all feedback",
                        notes: "Respond to every comment, message, and review today. Speed of response signals that you care — and that someone is home.",
                        relativeDueDays: 21,
                        priority: 2,
                        estimatedMinutes: 60,
                        isRecurring: true,
                        recurringInterval: .daily,
                        labels: ["launch", "support"]
                    ),
                    .init(
                        title: "Record end-of-day launch metrics",
                        notes: "Visits, signups, conversions, revenue. Write one honest sentence about how it went. This becomes your launch story.",
                        relativeDueDays: 21,
                        priority: 2,
                        estimatedMinutes: 20,
                        labels: ["launch", "analytics"]
                    ),
                ]
            ),
            .init(
                id: "pl-postlaunch",
                title: "Post-Launch",
                emoji: "📊",
                description: "The launch is the start, not the finish. Most real growth happens in the 30 days after.",
                tasks: [
                    .init(
                        title: "Compile week-one metrics report",
                        notes: "Traffic, conversions, revenue, top acquisition channels, top objections heard. Share with your team or an advisor — saying it out loud helps.",
                        relativeDueDays: 28,
                        priority: 2,
                        estimatedMinutes: 60,
                        labels: ["analytics", "review"]
                    ),
                    .init(
                        title: "Conduct 5 customer interviews",
                        notes: "Ask actual customers (and people who saw it but didn't buy — especially them): what made you sign up? What almost stopped you? What would you tell a friend?",
                        relativeDueDays: 28,
                        priority: 1,
                        estimatedMinutes: 150,
                        subtasks: [
                            .init(title: "Interview customer 1"),
                            .init(title: "Interview customer 2"),
                            .init(title: "Interview customer 3"),
                            .init(title: "Interview customer 4"),
                            .init(title: "Interview customer 5"),
                        ],
                        labels: ["research", "review"]
                    ),
                    .init(
                        title: "Prioritize top 3 improvements for v2",
                        notes: "Based on customer interviews: which 3 improvements would have the biggest impact on conversion or retention? Write them as outcomes, not features.",
                        relativeDueDays: 30,
                        priority: 2,
                        estimatedMinutes: 60,
                        labels: ["planning", "v2"]
                    ),
                ]
            ),
        ]
    )

    // MARK: - Home Renovation

    static let homeRenovation = PremiumTemplate(
        id: "premium-home-renovation",
        name: "Home Renovation",
        description: "From first quote to final walkthrough — complete renovation project tracking with contractor management, budget oversight, and a structured punch list.",
        icon: "hammer",
        colorHex: "#8B5E3C",
        category: "Life & Personal",
        howToUse: """
        Apply this template when starting a renovation project. Complete the Planning tasks on day one — especially the budget and contractor selection tasks. Skipping the planning phase is the #1 cause of renovation cost overruns. The daily site check task in the Construction section recurs automatically so you stay on top of progress without forgetting.
        """,
        sections: [
            .init(
                id: "hr-planning",
                title: "Planning",
                emoji: "📐",
                description: "Decisions made here save 3× their effort later. Don't rush this phase.",
                tasks: [
                    .init(
                        title: "Define project scope and set budget",
                        notes: "Write down exactly what's in scope and what's not. Set a hard budget limit and add a 20% contingency — every renovation costs more than the quote. Every single one.",
                        relativeDueDays: 0,
                        priority: 1,
                        estimatedMinutes: 60,
                        subtasks: [
                            .init(title: "List all rooms/areas in scope"),
                            .init(title: "List items explicitly OUT of scope"),
                            .init(title: "Set hard budget limit"),
                            .init(title: "Add 20% contingency buffer"),
                        ],
                        labels: ["planning", "budget"]
                    ),
                    .init(
                        title: "Get at least 3 contractor quotes",
                        notes: "Don't go with the cheapest. Go with the one who communicates best, has strong references, and can explain exactly what's included in their quote.",
                        relativeDueDays: 3,
                        priority: 1,
                        estimatedMinutes: 180,
                        subtasks: [
                            .init(title: "Request quote from contractor 1"),
                            .init(title: "Request quote from contractor 2"),
                            .init(title: "Request quote from contractor 3"),
                            .init(title: "Check references for top 2 candidates"),
                            .init(title: "Sign contract with chosen contractor"),
                        ],
                        labels: ["contractor", "planning"]
                    ),
                    .init(
                        title: "Order all materials and confirm delivery windows",
                        notes: "Don't wait for the contractor to do this. Long-lead items (tile, custom cabinets, fixtures) can delay the whole project by weeks if ordered late.",
                        relativeDueDays: 7,
                        priority: 2,
                        estimatedMinutes: 120,
                        labels: ["materials", "planning"]
                    ),
                    .init(
                        title: "Confirm permits and inspection schedule",
                        notes: "Ask your contractor: what permits are needed, who pulls them, and what inspections are required? Get it in writing. Permit issues are the most expensive delays.",
                        relativeDueDays: 5,
                        priority: 2,
                        estimatedMinutes: 30,
                        labels: ["permits", "planning"]
                    ),
                ]
            ),
            .init(
                id: "hr-construction",
                title: "Construction",
                emoji: "🔨",
                description: "Daily oversight keeps small issues from becoming expensive ones.",
                tasks: [
                    .init(
                        title: "Daily site walkthrough",
                        notes: "10 minutes. Walk through every area being worked on. Ask questions if anything looks wrong — it's always cheaper to fix issues in progress than after the fact.",
                        relativeDueDays: 14,
                        priority: 2,
                        estimatedMinutes: 15,
                        isRecurring: true,
                        recurringInterval: .daily,
                        labels: ["oversight", "recurring"]
                    ),
                    .init(
                        title: "Weekly progress photo documentation",
                        notes: "Same angles every week. These are invaluable for disputes, insurance claims, and for looking back at the transformation later.",
                        relativeDueDays: 14,
                        priority: 3,
                        estimatedMinutes: 15,
                        isRecurring: true,
                        recurringInterval: .weekly,
                        labels: ["documentation", "recurring"]
                    ),
                    .init(
                        title: "Review and approve mid-project invoice",
                        notes: "Check the invoice against the contract milestones. Only pay for completed work. Never release the final payment until the punch list is fully cleared.",
                        relativeDueDays: 21,
                        priority: 2,
                        estimatedMinutes: 30,
                        labels: ["payment", "budget"]
                    ),
                ]
            ),
            .init(
                id: "hr-finishing",
                title: "Finishing",
                emoji: "✨",
                description: "The punch list phase is where your contractor's quality really shows. Be thorough.",
                tasks: [
                    .init(
                        title: "Create detailed punch list",
                        notes: "Walk through every area with your contractor. Be specific: 'paint missed corner on west wall of bedroom' not 'touch up paint.' Vague punch lists produce vague results.",
                        relativeDueDays: 28,
                        priority: 1,
                        estimatedMinutes: 60,
                        labels: ["punch-list", "finishing"]
                    ),
                    .init(
                        title: "Schedule and pass all final inspections",
                        notes: "Confirm which inspections are required. Don't release final payment until all inspections pass. Permits closed = project done.",
                        relativeDueDays: 30,
                        priority: 1,
                        estimatedMinutes: 60,
                        labels: ["permits", "inspection"]
                    ),
                    .init(
                        title: "Professional deep clean",
                        notes: "Hire a post-construction cleaner — it's a different category of dirty than normal housekeeping. Worth every dollar.",
                        relativeDueDays: 35,
                        priority: 2,
                        estimatedMinutes: 30,
                        labels: ["finishing"]
                    ),
                    .init(
                        title: "Final walkthrough and release final payment",
                        notes: "Walk through the completed punch list together. Confirm every item is resolved. Take final photos. Then — and only then — release the final payment.",
                        relativeDueDays: 35,
                        priority: 1,
                        estimatedMinutes: 60,
                        labels: ["payment", "finishing"]
                    ),
                ]
            ),
        ]
    )

    // MARK: - Morning Power Hour

    static let morningPowerHour = PremiumTemplate(
        id: "premium-morning-power-hour",
        name: "Morning Power Hour",
        description: "A structured 60-minute morning routine covering mindset, movement, and your day's most important work — designed to complete before your first meeting.",
        icon: "sunrise",
        colorHex: "#F5A623",
        category: "featured",
        howToUse: """
        All tasks are set to daily recurring so they reappear automatically. Work through the sections in order: Mind & Body first, then Priorities, then Deep Work. Resist the urge to check email or Slack until the Priorities section — the whole point is to proactively shape your day before the world reacts to you.
        """,
        sections: [
            .init(
                id: "mph-mind",
                title: "Mind & Body",
                emoji: "🧘",
                description: "Prime your nervous system and mental state before touching a screen.",
                tasks: [
                    .init(
                        title: "Journal for 5 minutes",
                        notes: "No structure required. Could be 3 things you're grateful for, a brain dump of what's on your mind, or a single sentence about your intention for today. Just write.",
                        relativeDueDays: 0,
                        priority: 2,
                        estimatedMinutes: 5,
                        isRecurring: true,
                        recurringInterval: .daily,
                        labels: ["routine", "mindset"]
                    ),
                    .init(
                        title: "10 minutes of movement",
                        notes: "Walk, stretch, yoga, pushups — anything. Move your body before sitting at a screen. Even 10 minutes meaningfully improves focus and mood for the next 3 hours.",
                        relativeDueDays: 0,
                        priority: 2,
                        estimatedMinutes: 10,
                        isRecurring: true,
                        recurringInterval: .daily,
                        labels: ["routine", "health"]
                    ),
                    .init(
                        title: "Water and breakfast before caffeine",
                        notes: "16oz of water before coffee. You've been fasting for 8 hours — hydrate first. Protein-forward breakfast if possible. Your brain runs on glucose, not just caffeine.",
                        relativeDueDays: 0,
                        priority: 3,
                        estimatedMinutes: 10,
                        isRecurring: true,
                        recurringInterval: .daily,
                        labels: ["routine", "health"]
                    ),
                ]
            ),
            .init(
                id: "mph-priorities",
                title: "Daily Priorities",
                emoji: "🎯",
                description: "Set a clear north star before meetings and messages pull you into reactive mode.",
                tasks: [
                    .init(
                        title: "Review schedule and confirm top 3 priorities",
                        notes: "Look at your calendar and task list. What are the 3 outcomes that would make today a win? Write them down — ideally with a pen, not just in an app.",
                        relativeDueDays: 0,
                        priority: 1,
                        estimatedMinutes: 10,
                        isRecurring: true,
                        recurringInterval: .daily,
                        subtasks: [
                            .init(title: "Priority 1 — the most important outcome today"),
                            .init(title: "Priority 2"),
                            .init(title: "Priority 3"),
                        ],
                        labels: ["routine", "planning"]
                    ),
                    .init(
                        title: "Process yesterday's unfinished items",
                        notes: "Anything that didn't get done yesterday: reschedule with intent, delegate, or delete. Don't let yesterday's list bleed into today as passive guilt.",
                        relativeDueDays: 0,
                        priority: 2,
                        estimatedMinutes: 5,
                        isRecurring: true,
                        recurringInterval: .daily,
                        labels: ["routine", "planning"]
                    ),
                ]
            ),
            .init(
                id: "mph-deepwork",
                title: "Deep Work Sprint",
                emoji: "🔥",
                description: "Use your peak morning energy on the one thing that moves the needle most.",
                tasks: [
                    .init(
                        title: "First focus session: work on priority #1",
                        notes: "Phone face down. Notifications off. Close all unneeded browser tabs. Set a 45-minute timer. Your only job for the next 45 minutes is this one thing. Go.",
                        relativeDueDays: 0,
                        priority: 1,
                        estimatedMinutes: 45,
                        isRecurring: true,
                        recurringInterval: .daily,
                        labels: ["routine", "deep-work"]
                    ),
                    .init(
                        title: "5-minute transition break",
                        notes: "Walk away from the screen. Stretch. Don't open social media. This break is what makes the next session possible — protect it.",
                        relativeDueDays: 0,
                        priority: 3,
                        estimatedMinutes: 5,
                        isRecurring: true,
                        recurringInterval: .daily,
                        labels: ["routine"]
                    ),
                    .init(
                        title: "Check messages and handle urgent items",
                        notes: "You've earned it. 15 minutes max. Flag anything that needs a proper response and schedule time for it — don't try to handle everything now.",
                        relativeDueDays: 0,
                        priority: 3,
                        estimatedMinutes: 15,
                        isRecurring: true,
                        recurringInterval: .daily,
                        labels: ["routine", "communication"]
                    ),
                ]
            ),
        ]
    )
}
