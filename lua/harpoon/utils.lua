local Path = require("plenary.path")
local data_path = vim.fn.stdpath("data")
local last_project_file = string.format("%s/harpoon_last_proj", data_path)
local Job = require("plenary.job")
local Dev = require("harpoon.dev")
local log = Dev.log

local M = {}

M.data_path = data_path

function M.project_key()
    return vim.loop.cwd()
end

local function parse_projects()
    local names = {}
    for key in pairs(HarpoonConfig.projects) do
        table.insert(names, key)
    end

    return names
end

function M.project_candidates(ArgLead, CmdLine, CursorPos)
    return parse_projects()
end

function M.load_project_by_name_cli(opts)
    Path:new(last_project_file):write(opts.fargs[1], "w")
end

local function read_config(config)
    log.info(config)
    return Path:new(config):read()
end

function M.project_by_name_last_key()
    local ok, project = pcall(read_config, last_project_file)
    return project or "default"
end

function M.branch_key()
    local branch

    -- use tpope's fugitive for faster branch name resolution if available
    if vim.fn.exists("*FugitiveHead") == 1 then
        branch = vim.fn["FugitiveHead"]()
        -- return "HEAD" for parity with `git rev-parse` in detached head state
        if #branch == 0 then
            branch = "HEAD"
        end
    else
        -- `git branch --show-current` requires Git v2.22.0+ so going with more
        -- widely available command
        branch = M.get_os_command_output({
            "git",
            "rev-parse",
            "--abbrev-ref",
            "HEAD",
        })[1]
    end

    if branch then
        return vim.loop.cwd() .. "-" .. branch
    else
        return M.project_key()
    end
end

function M.normalize_path(item)
    return Path:new(item):make_relative(M.project_key())
end

function M.get_os_command_output(cmd, cwd)
    if type(cmd) ~= "table" then
        print("Harpoon: [get_os_command_output]: cmd has to be a table")
        return {}
    end
    local command = table.remove(cmd, 1)
    local stderr = {}
    local stdout, ret = Job
        :new({
            command = command,
            args = cmd,
            cwd = cwd,
            on_stderr = function(_, data)
                table.insert(stderr, data)
            end,
        })
        :sync()
    return stdout, ret, stderr
end

function M.split_string(str, delimiter)
    local result = {}
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

function M.is_white_space(str)
    return str:gsub("%s", "") == ""
end

return M
