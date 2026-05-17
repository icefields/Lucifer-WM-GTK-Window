-- Busted helper: add project root to package.path
-- Place this in tests/ so requires find ../ansi2pango and ../logic
local project_root = debug.getinfo(1, "S").source:match("^@(.*/)") .. "../"
package.path = project_root .. "?.lua;" .. package.path

-- Also add the project root lgi modules if needed
package.cpath = project_root .. "lgi/?.so;" .. package.cpath