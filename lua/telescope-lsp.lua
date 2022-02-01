local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local strings = require "plenary.strings"
local entry_display = require "telescope.pickers.entry_display"

local code_lens = function(opts)
    opts = opts or {}
    
    local tdi = vim.lsp.util.make_text_document_params()
    local lsp_results, err = vim.lsp.buf_request_sync(
    0,
    "textDocument/codeLens",
    {
        textDocument = tdi,
    },
    vim.F.if_nil(opts.timeout, 10000)
    )

    if err then
        print("ERROR: " .. err)
        return
    end

    if not lsp_results or vim.tbl_isempty(lsp_results) then
        print "No results from textDocument/codeLens"
        return
    end

    local line, _ = unpack(vim.api.nvim_win_get_cursor(0))
    line = line - 1

    local results = {}
    local widths = {
        title = 0,
        client_name = 0,
    }

    for client_id, response in pairs(lsp_results) do
        if response.result then
            local client = vim.lsp.get_client_by_id(client_id)

            for _, result in pairs(response.result) do
                if result.range.start.line == line then
                    local entry = {
                        title = result.command.title,
                        client = client,
                        client_name = client and client.name or "",
                        command = result,
                    }

                    for key, value in pairs(widths) do
                        widths[key] = math.max(value, strings.strdisplaywidth(entry[key]))
                    end

                    table.insert(results, entry)
                end
            end
        end
    end

    if #results == 0 then
        print "No code actions available"
        return
    end

    local function execute_action(action, client, client_name)
        local command = action.command
        local fn = client.commands[command.command] or vim.lsp.commands[command.command]
        if fn then
            fn(command, { bufnr = bufnr, client_id = client_name })
            return
        end

        local command_provider = client.server_capabilities.executeCommandProvider
        local commands = type(command_provider) == 'table' and command_provider.commands or {}
        if vim.tbl_contains(commands, command.command) then
            client.request('workspace/executeCommand', command, function(...)
                local result = vim.lsp.handlers['workspace/executeCommand'](...)
                --M.refresh()
                return result
            end, bufnr)
        end

        print "Codelens command not found"
    end

    if #results == 1 then
        result = results[1]
        execute_action(result.command, result.client, result.client_name)
        return
    end

    local displayer = entry_display.create {
        separator = " ",
        items = {
            { width = widths.title },
            { width = widths.client_name },
        },
    }

    local function make_display(entry)
        return displayer {
            { entry.value.title },
            { entry.value.client_name, "TelescopeResultsComment" },
        }
    end


    pickers.new(opts, {
        prompt_title = "LSP CodeLens",
        finder = finders.new_table {
            results = results,
            entry_maker = function(command)
                return {
                    value = command,
                    ordinal = command.title,
                    display = make_display,
                }
            end
        },
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()

                local action = selection.value.command
                local client = selection.value.client

                execute_action(action, client, selection.value.client_name)
            end)
            return true
        end,
        sorter = conf.generic_sorter(opts)
    }):find()
end

return {
    code_lens = code_lens
}

