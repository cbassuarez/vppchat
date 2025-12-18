//
//  WelcomeMarkdown.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import Foundation

enum WelcomeMarkdown {
    static let canonical: String =
"""
Welcome to **VPP Studio** 👋

This is the **single canonical Welcome chat** shared across **Console / Studio / Atlas**.

### How this app is structured
**Project ▸ Topic ▸ Chat ▸ Messages**
- **Conversations** are “turns” (Console shows the same thing).
- **Documents** are saved notes (from Console “Save block”, etc.).

### How to talk to the system (VPP)
Start your message with a tag on line 1:
- `!<g>` grounding / concept
- `!<q>` questions
- `!<o>` outputs / implementation
- `!<c>` corrections

### Try this now
```text
!<g>
What are we building, and what should I do next?
If you ever feel lost: open Command Space, search “Welcome”, and jump back here.
"""
}
