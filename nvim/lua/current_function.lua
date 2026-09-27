local M = {}

local identifier_types = {
    field_identifier = true,
    identifier = true,
    property_identifier = true,
    type_identifier = true,
}

local function_types = {
    arrow_function = true,
    closure_expression = true,
    ["function"] = true,
    function_declaration = true,
    function_definition = true,
    function_expression = true,
    function_item = true,
    lambda_expression = true,
    local_function = true,
    method = true,
    method_declaration = true,
    method_definition = true,
    singleton_method = true,
}

local function first_field(node, field)
    local nodes = node:field(field)
    return nodes and nodes[1]
end

local function first_identifier(node, max_depth)
    if not node or max_depth < 0 then
        return nil
    end

    if identifier_types[node:type()] then
        return node
    end

    for child in node:iter_children() do
        local found = first_identifier(child, max_depth - 1)
        if found then
            return found
        end
    end
end

local function function_name_node(function_node)
    local direct_name = first_field(function_node, "name")
    if direct_name then
        return first_identifier(direct_name, 4) or direct_name
    end

    local declarator_name = first_identifier(first_field(function_node, "declarator"), 4)
    if declarator_name then
        return declarator_name
    end

    -- Handle anonymous functions assigned to a name, e.g. `const foo = () => {}`.
    local parent = function_node:parent()
    local parent_name = parent
        and (first_field(parent, "name") or first_field(parent, "key") or first_field(parent, "left"))

    if parent_name then
        return first_identifier(parent_name, 4) or parent_name
    end
end

function M.name()
    local ok, node = pcall(vim.treesitter.get_node, { bufnr = 0 })
    if not ok or not node then
        vim.notify("No Tree-sitter node found for current buffer", "warn")
        return
    end

    while node do
        if function_types[node:type()] then
            local name_node = function_name_node(node)
            if name_node then
                return vim.treesitter.get_node_text(name_node, 0)
            end
        end

        node = node:parent()
    end

    vim.notify("Not inside a named function", "warn")
end

return M
