local C = minetest.colorize
local items_per_page = 63
--===================================================================================================================---
local function get_last_sale_id()
    local file_path = minetest.get_worldpath() .. "/item_exchange_plus.txt"
    local file = io.open(file_path, "r")
    if not file then
        return 0
    end
    local last_id = 0
    for line in file:lines() do
        local id = tonumber(string.match(line, "%[(%d+)%]"))
        if id and id > last_id then
            last_id = id
        end
    end
    file:close()
    return last_id
end
--===================================================================================================================---
local function get_max_page(sales)
    local total_items = 0
    for _ in pairs(sales) do
        total_items = total_items + 1
    end
    return math.ceil(total_items / items_per_page)
end
--===================================================================================================================---
local function read_sales_from_file()
    local sales = {}
    local file_path = minetest.get_worldpath() .. "/item_exchange_plus.txt"
    local file = io.open(file_path, "r")
    if not file then
        return sales
    end
    for line in file:lines() do
        local sale_id, item_name = string.match(line, "%[(%d+)%].+Item:%s+%[(%S+)")
        if sale_id and item_name then
            sales[tonumber(sale_id)] = item_name
        end
    end
    file:close()
    return sales
end
--===================================================================================================================---
local function get_player_shop_page(player)
    local meta = player:get_meta()
    local page = meta:get_int("shop_page")
    if page == 0 then
        page = 1
        meta:set_int("shop_page", page)
    end
    return page
end
--===================================================================================================================---
local function set_player_shop_page(player, page)
    local meta = player:get_meta()
    meta:set_int("shop_page", page)
end
--===================================================================================================================---
local function generate_item_buttons(formspec, sales, page)
    local x = 8.5
    local y = 0.25
    local start_index = (page - 1) * items_per_page
    local end_index = start_index + items_per_page - 1
    local counter = 0

    for sale_id, item_name in pairs(sales) do
        if counter >= start_index and counter <= end_index then
            formspec = formspec .. "item_image_button[" .. x .. "," .. y .. ";1,1;" .. item_name .. ";" .. sale_id .. ";]"
            x = x + 1
            if x > 15 then
                x = 8.5
                y = y + 1
            end
        end
        counter = counter + 1
    end
    return formspec
end
--===================================================================================================================---
local function add_common_elements(formspec)
    for i = 0, 7 do
        formspec = formspec .. "image[" .. i .. ",5.7;1,1;gui_hb_bg.png]"
    end

    formspec = formspec .. "background[-0.25,-0.25;15.95,10.5;bc.png]"
    formspec = formspec .. "tabheader[0,0;shop_tab;      Menu      ;1;true;false]"
    formspec = formspec .. "list[current_player;main;0,5.7;8,1;]"
    formspec = formspec .. "list[current_player;main;0,6.95;8,3;8]"
    formspec = formspec .. "listring[current_player;main]"
    formspec = formspec .. "list[current_player;sell_slot;0,3;1,1;]"
    formspec = formspec .. "list[current_player;sell_price_slot;2.5,3;1,1;]"
    formspec = formspec .. "image[1.25,3;1,1;gui_furnace_arrow_bg.png^[transformR270]"
    formspec = formspec .. "listring[current_player;sell_slot]"
    formspec = formspec .. "button[0,4.1;2,1;sell;Put up for sale]"
    formspec = formspec .. "button[8.5,9.125;2,1;prev;Prev page]"
    formspec = formspec .. "button[10.5,9.125;2,1;next;Next page]"
    return formspec
end
--===================================================================================================================---
local function open_shop_menu(player)
    local inv = player:get_inventory()
    inv:set_size("sell_slot", 1)
    inv:set_size("sell_price_slot", 1)

    local sales = read_sales_from_file()
    local page = get_player_shop_page(player)
    local max_page = get_max_page(sales)

    local formspec = "size[15.5,9.5]"
    formspec = generate_item_buttons(formspec, sales, page)
    formspec = add_common_elements(formspec)
    formspec = formspec .. "label[13.5,9.25;Page: " .. page .. "/" .. max_page .. "]"
    formspec = formspec .. "button[0,1.3;2,1;buy_nothing;Buy]"

    minetest.show_formspec(player:get_player_name(), "shop_menu", formspec)
end

--===================================================================================================================---
local function open_sale_information(player, sale_id)
    local page = get_player_shop_page(player)
    local sales = read_sales_from_file()
    local max_page = get_max_page(sales)

    local file_path = minetest.get_worldpath() .. "/item_exchange_plus.txt"
    local file = io.open(file_path, "r")
    if not file then
        minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] Error trying to open data backup file 'item_exchange_plus.txt'"))
        return
    end

    local sale_details
    for line in file:lines() do
        local id = tonumber(string.match(line, "%[(%d+)%]"))
        if id == sale_id then
            sale_details = line
            break
        end
    end
    file:close()

    if not sale_details then
        minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] This online offer is no longer available. The seller probably removed the ad or another player probably bought it before you."))
        return
    end

    local seller_name = string.match(sale_details, "([^%s]+)%s+Item:")
    local item_name = string.match(sale_details, "Item:%s+%[(%S+)")
    local item_count = tonumber(string.match(sale_details, "Item:%s+%[.-%s+(%d+)%]"))
    local price_name = string.match(sale_details, "Price:%s+%[(%S+)")
    local price_count = tonumber(string.match(sale_details, "Price:%s+%[.-%s+(%d+)%]"))

    local formspec = "size[15.5,9.5]"
    formspec = generate_item_buttons(formspec, sales, page)
    formspec = add_common_elements(formspec)

    if seller_name == player:get_player_name() then
        formspec = formspec .. "button[3.5,1.3;2,1;remove_" .. sale_id .. ";Remove]"
    end

    formspec = formspec .. "label[13.5,9.25;Page: " .. page .. "/" .. max_page .. "]"
    formspec = formspec .. "label[0,-0.15;Sale of " .. seller_name .. "]"
    formspec = formspec .. "item_image_button[0,0.25;1,1;" .. item_name .. " " .. item_count .. ";" .. item_name .. ";]"
    formspec = formspec .. "item_image_button[2.5,0.25;1,1;" .. price_name .. " " .. price_count .. ";" .. price_name .. ";]"
    formspec = formspec .. "image[1.25,0.25;1,1;gui_furnace_arrow_bg.png^[transformR270]"
    formspec = formspec .. "button[0,1.3;2,1;buy_" .. sale_id .. ";Buy]"

    minetest.show_formspec(player:get_player_name(), "sale_information_" .. sale_id, formspec)
end
--===================================================================================================================---
local function sell_items(player)
    local inv = player:get_inventory()
    local sell_items = inv:get_list("sell_slot")
    local sell_prices = inv:get_list("sell_price_slot")
    local player_name = player:get_player_name()

    local items_valid = false
    for _, item in ipairs(sell_items) do
        if not item:is_empty() then
            items_valid = true
            break
        end
    end

    local prices_valid = false
    for _, price in ipairs(sell_prices) do
        if not price:is_empty() then
            prices_valid = true
            break
        end
    end

    if items_valid and prices_valid then
        local last_id = get_last_sale_id()
        local sale_id = last_id + 1

        local file_path = minetest.get_worldpath() .. "/item_exchange_plus.txt"
        local file = io.open(file_path, "a")
        if not file then
            file = io.open(file_path, "w")
            if not file then
                minetest.chat_send_player(player_name, C("#a1bcd1", "[Server Shop] Error creating the data backup file 'item_exchange_plus.txt'."))
                return
            end
        end

        file:write("[" .. sale_id .. "] " .. player_name .. " ")
        for i, item in ipairs(sell_items) do
            local price = sell_prices[i]
            local item_name = item:get_name()
            local price_name = price:get_name()
            local item_count = item:get_count()
            local price_count = price:get_count()
            if not item:is_empty() and not price:is_empty() then
                file:write("Item: [" .. item_name .. " " ..  item_count .. "] Price: [" .. price_name .. " " .. price_count .. "]\n")
            end
        end
        file:close()

        inv:set_list("sell_slot", {})
        inv:set_list("sell_price_slot", {})

        open_shop_menu(player)
        minetest.chat_send_player(player_name, C("#a1bcd1", "[Server Shop] Your online sale has been recorded and published for other players to see. Happy selling!"))

        minetest.after(7, function()
            minetest.chat_send_all(C("#a1bcd1", "[Server Shop] New sale available online from " .. player_name .. "! Go watch it using the '/shop' command"))
        end)
    else
        minetest.chat_send_player(player_name, C("#a1bcd1", "[Server Shop] To be able to put your sale ad online, please make sure you fill in the two locations provided for this purpose for the items for sale."))
    end
end
--===================================================================================================================---
local function remove_sale(player, sale_id)
    local file_path = minetest.get_worldpath() .. "/item_exchange_plus.txt"
    local file = io.open(file_path, "r")
    if not file then
        minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] Error trying to open data backup file 'item_exchange_plus.txt'"))
        return
    end

    local sale_details
    local sale_line_number = 0
    local remaining_lines = {}
    for line in file:lines() do
        sale_line_number = sale_line_number + 1
        local id = tonumber(string.match(line, "%[(%d+)%]"))
        if id == sale_id then
            sale_details = line
        else
            table.insert(remaining_lines, line)
        end
    end
    file:close()

    if not sale_details then
        minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] Unable to find the sale to remove."))
        return
    end

    local price_name = string.match(sale_details, "Price:%s+%[(%S+)")
    local price_count = tonumber(string.match(sale_details, "Price:%s+%[.-%s+(%d+)%]"))
    local item_name = string.match(sale_details, "Item:%s+%[(%S+)")
    local item_count = tonumber(string.match(sale_details, "Item:%s+%[.-%s+(%d+)%]"))
    local player_inv = player:get_inventory()
    local leftover_count = player_inv:add_item("main", ItemStack(price_name .. " " .. price_count))
    if not leftover_count:is_empty() then
        minetest.add_item(player:get_pos(), leftover_count)
    end
    leftover_count = player_inv:add_item("main", ItemStack(item_name .. " " .. item_count))
    if not leftover_count:is_empty() then
        minetest.add_item(player:get_pos(), leftover_count)
    end

    file = io.open(file_path, "w")
    if not file then
        minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] Error trying to open data backup file 'item_exchange_plus.txt'"))
        return
    end
    for _, line in ipairs(remaining_lines) do
        file:write(line .. "\n")
    end
    file:close()

    open_shop_menu(player)
    minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] Sale removed successfully. Items and price returned to your inventory."))
end

--===================================================================================================================---
local function buy_item(player, sale_id)
    local file_path = minetest.get_worldpath() .. "/item_exchange_plus.txt"
    local file = io.open(file_path, "r")
    if not file then
        minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] Error trying to open data backup file 'item_exchange_plus.txt'"))
        return
    end

    local sale_details
    local sale_line_number = 0
    for line in file:lines() do
        sale_line_number = sale_line_number + 1
        local id = tonumber(string.match(line, "%[(%d+)%]"))
        if id == sale_id then
            sale_details = line
            break
        end
    end
    file:close()

    if not sale_details then
        minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] This online offer is no longer available. The seller probably removed the ad or another player probably bought it before you."))
        return
    end

    local price_name = string.match(sale_details, "Price:%s+%[(%S+)")
    local price_count = tonumber(string.match(sale_details, "Price:%s+%[.-%s+(%d+)%]"))
    local item_name = string.match(sale_details, "Item:%s+%[(%S+)")
    local item_count = tonumber(string.match(sale_details, "Item:%s+%[.-%s+(%d+)%]"))
    local seller_name = string.match(sale_details, "([^%s]+)%s+Item:")

    local player_inv_contains_price = player:get_inventory():contains_item("main", price_name)
    if not player_inv_contains_price then
        minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] You do not have the required item to buy this item."))
        return
    end

    local seller = minetest.get_player_by_name(seller_name)
    if seller then
        local leftover_count = seller:get_inventory():add_item("main", ItemStack(price_name .. " " .. price_count))
        if not leftover_count:is_empty() then
            minetest.add_item(seller:get_pos(), leftover_count)
        end
        minetest.chat_send_player(seller:get_player_name(), C("#a1bcd1", "[Server Shop] You have sold ") .. C("#5a8eb6", price_name .. " x" .. price_count) .. C("#a1bcd1", " to ") .. C("#5a8eb6", player:get_player_name()) .. ".")
    else
        local new_line = string.format("[ToGive] %s %s %s", seller_name, price_name, price_count)
        file = io.open(file_path, "a")
        if not file then
            minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] Error trying to open data backup file 'item_exchange_plus.txt'"))
            return
        end
        file:write(new_line .. "\n")
        file:close()

        local lines = {}
        file = io.open(file_path, "r")
        if not file then
            minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] Error trying to open data backup file 'item_exchange_plus.txt'"))
            return
        end
        for line in file:lines() do
            if line ~= sale_details then
                table.insert(lines, line)
            end
        end
        file:close()

        file = io.open(file_path, "w")
        if not file then
            minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] Error trying to open data backup file 'item_exchange_plus.txt'"))
            return
        end
        for _, line in ipairs(lines) do
            file:write(line .. "\n")
        end
        file:close()
    end

    local item_description = ""
    local item_def = minetest.registered_items[item_name]
    if item_def and item_def.description then
        item_description = item_def.description
    end

    local price_description = ""
    local price_def = minetest.registered_items[price_name]
    if price_def and price_def.description then
        price_description = price_def.description
    end

    local player_inv = player:get_inventory()
    local player_price_count = 0
    local player_main_list = player_inv:get_list("main")
    for _, stack in ipairs(player_main_list) do
        if stack:get_name() == price_name then
            player_price_count = player_price_count + stack:get_count()
        end
    end

    if player_price_count < price_count then
        minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] You do not have enough of the required item to buy this item."))
        return
    end
    local leftover_count = player_inv:add_item("main", ItemStack(item_name .. " " .. item_count))

    if not leftover_count:is_empty() then
        minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] Your inventory is full, as a result recently purchased items have been thrown on the ground at your feet."))
        minetest.add_item(player:get_pos(), leftover_count)
    end
    player_inv:remove_item("main", ItemStack(price_name .. " " .. price_count))

    local lines = {}
    file = io.open(file_path, "r")
    if not file then
        minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] Error trying to open data backup file 'item_exchange_plus.txt'"))
        return
    end
    for line in file:lines() do
        if line ~= sale_details then
            table.insert(lines, line)
        end
    end
    file:close()
    file = io.open(file_path, "w")
    if not file then
        minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] Error trying to open data backup file 'item_exchange_plus.txt'"))
        return
    end
    for _, line in ipairs(lines) do
        file:write(line .. "\n")
    end
    file:close()
    open_shop_menu(player)
    minetest.chat_send_player(player:get_player_name(), C("#a1bcd1", "[Server Shop] Purchase successful! You have bought ") .. C("#5a8eb6", item_description .. " (" .. item_name .. ") x" .. item_count) .. C("#a1bcd1", " from ") .. C("#5a8eb6", seller_name) .. C("#a1bcd1", " in exchange for ") .. C("#5a8eb6", price_description .. " (" .. price_name .. ") x" .. price_count) .. ".")
end
--===================================================================================================================---
minetest.register_on_player_receive_fields(function(player, formname, fields)
    for field, _ in pairs(fields) do
        if field == "next" then
            local page = get_player_shop_page(player)
            local max_page = math.ceil(get_last_sale_id() / items_per_page)
            if page < max_page then
                page = page + 1
                set_player_shop_page(player, page)
                open_shop_menu(player)
            end
        elseif field == "prev" then
            local page = get_player_shop_page(player)
            if page > 1 then
                page = page - 1
                set_player_shop_page(player, page)
                open_shop_menu(player)
            end
        else
            local sale_id = tonumber(field)
            if sale_id then
                open_sale_information(player, sale_id)
                break
            end
            if fields["sell"] then
                sell_items(player)
            elseif string.match(field, "^buy_%d+$") then
                local id = tonumber(string.match(field, "buy_(%d+)"))
                buy_item(player, id)
                break
            elseif string.match(field, "^remove_%d+$") then
                local id = tonumber(string.match(field, "remove_(%d+)"))
                remove_sale(player, id)
                break        
            end
        end
    end
end)
--===================================================================================================================---
minetest.register_chatcommand("shop", {
    description = "Open shop menu",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if player then
            set_player_shop_page(player, 1)
            open_shop_menu(player)
        end
    end,
})
--===================================================================================================================---
minetest.register_on_joinplayer(function(player)
    local file_path = minetest.get_worldpath() .. "/item_exchange_plus.txt"
    local file = io.open(file_path, "r")
    if not file then
        minetest.chat_send_player(player:get_player_name(), minetest.colorize("#a1bcd1", "[Server Shop] Error trying to open data backup file 'item_exchange_plus.txt'"))
        return
    end
    local to_give_items = {}
    local remaining_lines = {}
    local notification_message = ""

    for line in file:lines() do
        if string.match(line, "%[ToGive%]") then
            local seller_name, item_name, item_count = string.match(line, "%[ToGive%]%s+(%S+)%s+(%S+)%s+(%d+)")
            if seller_name == player:get_player_name() then
                table.insert(to_give_items, {name = item_name, count = tonumber(item_count)})
                notification_message = notification_message .. item_count .. "x " .. item_name .. ", "
            else
                table.insert(remaining_lines, line)
            end
        else
            table.insert(remaining_lines, line)
        end
    end
    file:close()
    file = io.open(file_path, "w")
    if not file then
        minetest.chat_send_player(player:get_player_name(), minetest.colorize("#a1bcd1", "[Server Shop] Error trying to open data backup file 'item_exchange_plus.txt'"))
        return
    end
    for _, line in ipairs(remaining_lines) do
        file:write(line .. "\n")
    end
    file:close()
    local player_inv = player:get_inventory()
    local items_added = false

    for _, item_data in ipairs(to_give_items) do
        local leftover_count = player_inv:add_item("main", ItemStack(item_data.name .. " " .. item_data.count))
        if not leftover_count:is_empty() then
            minetest.add_item(player:get_pos(), ItemStack(item_data.name .. " " .. leftover_count:get_count()))
            items_added = true
        else
            items_added = false
        end
    end

    if notification_message ~= "" then
        notification_message = string.sub(notification_message, 1, -3)
        local message_prefix = ""
        if items_added then
            message_prefix = "[Server Shop] A player purchased items from your sales. However, your inventory is full, so the items were left on the ground at your feet: "
        else
            message_prefix = "[Server Shop] A player has purchased items from your sale and they were added to your inventory: "
        end
        minetest.chat_send_player(player:get_player_name(), minetest.colorize("#a1bcd1", message_prefix .. notification_message))
    end
end)