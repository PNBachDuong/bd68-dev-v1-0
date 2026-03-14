# BD68 Project Overlay
# ============================================================
# Hướng dẫn:
#   - Chỉ điền sections liên quan đến project này
#   - Xóa sections không dùng để giảm token
#   - Agent load file này SAU BD68_PROFILE — values ở đây override global
# ============================================================

## Identity
project: ""
type: ""        # web-app | api-backend | mobile | cli | library
phase: ""       # build | test | staging | production
last_updated: ""

## Stack
runtime: []
frameworks: []
key_libs: []

## Library Docs Sources
# Agent query Context7/chub với sources này TRƯỚC khi dùng generic search
docs: []
# Ví dụ:
# docs:
#   - lib: react
#     source: https://react.dev
#     priority: high
#   - lib: fastapi
#     source: https://fastapi.tiangolo.com
#     priority: high

## Code Style Overrides
# Ghi đè rules trong BD68_PROFILE cho project này
overrides: []
# Ví dụ:
# overrides:
#   - rule: indent
#     value: 4-space
#   - rule: quote-style
#     value: double

## Architecture Decisions — LOCKED
# Những gì đã chốt — agent KHÔNG được suggest thay đổi
locked: []
# Ví dụ:
# locked:
#   - "State management: Zustand only, không dùng Redux"
#   - "API layer: tất cả calls đi qua /src/services/, không gọi direct từ component"

## Constraints
# Những gì KHÔNG làm trong project này
never: []
# Ví dụ:
# never:
#   - "Không dùng class components"
#   - "Không commit .env files"
#   - "Không thêm dependency mới khi chưa hỏi"

## Active Context
# Cập nhật mỗi khi bắt đầu session mới
current_milestone: ""
current_focus: ""
known_blockers: []
