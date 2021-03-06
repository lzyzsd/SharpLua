--[[
TODO:
Better error messages

LASM (Lua Assembly) is used to write Lua bytecode.

Controls:
[] - Optional

.const Value
Value = "String", true/false/nil, Number
.local Name     <StartPC, EndPC = 0, 0>
.upval Name
.upvalue Name
.stacksize Value
.maxstacksize value
.vararg <Vararg int value>
.name Name
.options

.func [name]
.function [name]
.end

Opcodes:
<code> <arg> <arg> <arg>
The 'C' arg is optional, and defaults to 0
]]

require"LuaFile"
require"Chunk"
require"bin"
require"Instruction"

Parser = {
    new = function(self)
        return setmetatable({ }, { __index = self })
    end,
    
    Parse = function(self, text)
        local file = LuaFile:new()
        local index = 1
        local lineNumber = 1
        local func = file.Main
        file.Main.Vararg = 2
        file.Main.Name = "LASM Chunk"
        funcStack = { }
        
        local function parseControl(line)
            local ll = line:lower()
            if ll:sub(1, 6) == ".const" then
                local l = line:sub(7)
                while l:sub(1, 1) == " " or l:sub(1, 1) == "\t" do
                    l = l:sub(2) -- strip whitespace
                end
                local value = readValue(l)
                if value == true or value == false then
                    func.Constants[func.Constants.Count] = Constant:new("Bool", value)
                elseif value == nil then
                    func.Constants[func.Constants.Count] = Constant:new("Nil", nil)
                elseif type(value) == "number" then
                    func.Constants[func.Constants.Count] = Constant:new("Number", value)
                elseif type(value) == "string" then
                    func.Constants[func.Constants.Count] = Constant:new("String", value)
                end
            elseif ll:sub(1, 5) == ".name" then
                -- Im lazy :P
                local l = line:sub(6)
                while l:sub(1, 1) == " " or l:sub(1, 1) == "\t" do l = l:sub(2) end
                if l:sub(1, 1) == "\"" then
                    func.Name = loadstring("return " .. l)()
                else
                    while l:sub(-1, -1) == " " or l:sub(-1, -1) == "\t" do l = l:sub(1, -2) end
                    func.Name = l
                end
            elseif ll:sub(1, 8) == ".options" then
                local l = line:sub(9)
                local t = { }
                -- Pattern matching time!
                local pattern = "([%d.]*)"
                for w in string.gmatch(l, pattern) do
                    if w and w ~= "" then
                        table.insert(t, tonumber(w) or error("Cannot convert '" .. w .. "' to a number!"))
                    end
                end
                func.UpvalueCount = t[1] or func.UpvalueCount
                func.ArgumentCount = t[2] or func.ArgumentCount
                func.Vararg = t[3] or func.Vararg
                func.MaxStackSize = t[4] or func.MaxStackSize
            elseif ll:sub(1, 6) == ".local" then
                local l = line:sub(7)
                while l:sub(1, 1) == " " or l:sub(1, 1) == "\t" do
                    l = l:sub(2) -- strip whitespace
                end
                while l:sub(-1, -1) == " " or l:sub(-1, -1) == "\t" do
                    l = l:sub(1, -2) -- strip ending whitespace
                end
                if l:sub(1, 1) == "\"" then
                    func.Locals[func.Locals.Count] = Local:new(loadstring("return " .. l)(), 0, 0)
                else
                    func.Locals[func.Locals.Count] = Local:new(l, 0, 0)
                end
            elseif ll:sub(1, 6) == ".upval" then
                local l = line:sub(7)
                while l:sub(1, 1) == " " or l:sub(1, 1) == "\t" do
                    l = l:sub(2) -- strip whitespace
                end
                while l:sub(-1, -1) == " " or l:sub(-1, -1) == "\t" do
                    l = l:sub(1, -2) -- strip ending whitespace
                end
                if l:sub(1, 1) == "\"" then
                    func.Upvalues[func.Upvalues.Count] = { Name = loadstring("return " .. l)() }
                else
                    func.Upvalues[func.Upvalues.Count] = { Name = l }
                end
            elseif ll:sub(1, 8) == ".upvalue" then
                local l = line:sub(9)
                while l:sub(1, 1) == " " or l:sub(1, 1) == "\t" do
                    l = l:sub(2) -- strip whitespace
                end
                while l:sub(-1, -1) == " " or l:sub(-1, -1) == "\t" do
                    l = l:sub(1, -2) -- strip ending whitespace
                end
                if l:sub(1, 1) == "\"" then
                    func.Upvalues[func.Upvalues.Count] = { Name = loadstring("return " .. l)() }
                else
                    func.Upvalues[func.Upvalues.Count] = { Name = l }
                end
            elseif ll:sub(1, 10) == ".stacksize" then
                local l = line:sub(11)
                while l:sub(1, 1) == " " or l:sub(1, 1) == "\t" do
                    l = l:sub(2) -- strip whitespace
                end
                local n = tonumber(l)
                if not n then error("Unable to parse '" .. l .. "' into a number!") end
                if math.floor(n) ~= n then error("Not a valid integer '" .. n .. "'!") end
                func.MaxStackSize = n
            elseif ll:sub(1, 13) == ".maxstacksize" then
                local l = line:sub(14)
                while l:sub(1, 1) == " " or l:sub(1, 1) == "\t" do
                    l = l:sub(2) -- strip whitespace
                end
                local n = tonumber(l)
                if not n then error("Unable to parse '" .. l .. "' into a number!") end
                if math.floor(n) ~= n then error("Not a valid integer '" .. n .. "'!") end
                func.MaxStackSize = n
            elseif ll:sub(1, 7) == ".vararg" then
                local l = line:sub(8)
                while l:sub(1, 1) == " " or l:sub(1, 1) == "\t" do
                    l = l:sub(2) -- strip whitespace
                end
                local n = tonumber(l)
                if not n then error("Unable to parse '" .. l .. "' into a number!") end
                if math.floor(n) ~= n then error("Not a valid integer '" .. n .. "'!") end
                func.Vararg = n
            elseif ll:sub(1, 9) == ".function" then
                local l = line:sub(10)
                while l:sub(1, 1) == " " or l:sub(1, 1) == "\t" do
                    l = l:sub(2) -- strip whitespace
                end
                while l:sub(-1, -1) == " " or l:sub(-1, -1) == "\t" do
                    l = l:sub(1, -2) -- strip ending whitespace
                end
                local n = Chunk:new()
                n.FirstLine = lineNumber
                if l:len() > 0 then
                    if l:sub(1, 1) == "\"" then
                        n.Name = loadstring("return " .. l)()
                    else
                        n.Name = l
                    end
                end
                getmetatable(func.Protos).__newindex(func.Protos, func.Protos.Count, n)
                funcStack[#funcStack + 1] = func
                func = n
            elseif ll:sub(1, 5) == ".func" then
                local l = line:sub(6)
                while l:sub(1, 1) == " " or l:sub(1, 1) == "\t" do
                    l = l:sub(2) -- strip whitespace
                end
                while l:sub(-1, -1) == " " or l:sub(-1, -1) == "\t" do
                    l = l:sub(1, -2) -- strip ending whitespace
                end
                local n = Chunk:new()
                n.FirstLine = lineNumber
                if l:len() > 0 then
                    if l:sub(1, 1) == "\"" then
                        n.Name = loadstring("return " .. l)()
                    else
                        n.Name = l
                    end
                end
                getmetatable(func.Protos).__newindex(func.Protos, func.Protos.Count, n)
                funcStack[#funcStack + 1] = func
                func = n
            elseif ll:sub(1, 4) == ".end" then
                local f = table.remove(funcStack)
                func.LastLine = lineNumber
                local instr1 = func.Instructions[func.Instructions.Count - 1]
                local instr2 = Instruction:new("RETURN")
                instr2.A = 0
                instr2.B = 1
                instr2.C = 0
                if instr1 then
                    if instr1.Opcode ~= "RETURN" then
                        getmetatable(func.Instructions).__newindex(func.Instructions, func.Instructions.Count, instr2)
                        --table.insert(func.Instructions, func.Instructions.Count, instr2)
                    end
                else
                    getmetatable(func.Instructions).__newindex(func.Instructions, 0, instr2)
                end 
                    
                func = f
            else
                error("Invalid Control")
            end
        end
        
        local function parseOpcode(line)
            local tn = _G.tonumber or tonumber
            local function tonumber(s)
                if s:sub(1, 1) == "$" or s:sub(1, 1):upper() == "R" or s:sub(1, 1) == "k" then
                    s = s:sub(2)
                end
                return tn(s) or error("Unable to convert '" .. s .. "' to a number!")
            end
            
            local op = ""
            local i = 1
            local l = line:lower()
            while true do
                local c = l:sub(i, i)
                if "a" <= c and c <= "z" then -- reads a character
                    op = op .. c
                else
                    break
                end
                i = i + 1
            end
            local instr = Instruction:new(op, 0)
            if not instr.Opcode then
                error("Unknown opcode :" .. op)
            end
            line = line:sub(i + 1)
            i = 1
            if instr.OpcodeType == "ABC" then
                local a, b, c = "", "", ""
                local inA, inB = true, false
                while true do
                    local char = line:sub(i, i)
                    if char == "\t" or char == " " or char == "" then
                        if inA then
                            inB = true
                            inA = false
                        elseif inB then
                            inB = false
                        else
                            break
                        end
                    else
                        if inA then
                            a = a .. char
                        elseif inB then
                            b = b .. char
                        else
                            c = c .. char
                        end
                    end
                    i = i + 1
                end
                c = c == "" and "0" or c
                instr.A = tonumber(a)
                instr.B = tonumber(b)
                instr.C = tonumber(c)
            elseif instr.OpcodeType == "ABx" then
                local a, bx = "", ""
                local inA = true
                while true do
                    local char = line:sub(i, i)
                    if char == "\t" or char == " " or char == "" then
                        if inA then
                            inA = false
                        else
                            break
                        end
                    else
                        if inA then
                            a = a .. char
                        else
                            bx = bx .. char
                        end
                    end
                    i = i + 1
                end
                instr.A = tonumber(a)
                instr.Bx = tonumber(bx)
            elseif instr.OpcodeType == "AsBx" then
                local a, sbx = "", ""
                local inA = true
                while true do
                    local char = line:sub(i, i)
                    if char == "\t" or char == " " or char == "" then
                        if inA then
                            inA = false
                        else
                            break
                        end
                    else
                        if inA then
                            a = a .. char
                        else
                            sbx = sbx .. char
                        end
                    end
                    i = i + 1
                end
                instr.A = tonumber(a)
                instr.sBx = tonumber(sbx)
            end
            return instr
        end
        
        local function readVarName()
            local varPattern = "([%w_]*)" -- Any letter, number, or underscore
            local varName = string.match(text, varPattern, index)
            if not varName then
                error("Invalid variable name!")
            end
            index = index + varName:len()
            return varName
        end
        
        local function readComment()
            if text:sub(index, index) == ";" then
                while true do
                    local char = text:sub(index, index)
                    if char == "\r" then
                        index = index + 1
                        if text:sub(index, index) == "\n" then
                            index = index + 1
                        end
                        break
                    elseif char == "\n" then
                        index = index + 1
                        break
                    elseif char == "" then
                        break
                    else
                    end
                    index = index + 1
                end
            end
        end
        
        function readValue(text)
            local index = 1
            if text:sub(index, index) == "\"" then
                local s = ""
                index = index + 1
                while true do
                    local c = text:sub(index, index)
                    if c == "\\" then
                        local c2 = c .. text:sub(index + 1, index + 1)
                        if c2 == "\\n" then
                            s = s .. "\n"
                        elseif c2 == "\\r" then
                            s = s .. "\r"
                        elseif c2 == "\\t" then
                            s = s .. "\t"
                        elseif c2 == "\\\\" then
                            s = s .. "\\"
                        elseif c2 == "\\\"" then
                            s = s .. "\""
                        elseif c2 == "\\'" then
                            s = s .. "'"
                        elseif c2 == "\\a" then
                            s = s .. "\a"
                        elseif c2 == "\\b" then
                            s = s .. "\b"
                        elseif c2 == "\\f" then
                            s = s .. "\f"
                        elseif c2 == "\\v" then
                            s = s .. "\v"
                        elseif string.find(c2, "\\%d") then
                            local ch = text:sub(index + 1, index + 1)
                            if string.find(text:sub(index + 2, index + 2), "%d") then
                                index = index + 1
                                ch = ch .. text:sub(index + 1, index + 1)
                                if string.find(text:sub(index + 2, index + 2), "%d") then
                                    index = index + 1
                                    ch = ch .. text:sub(index + 1, index + 1)
                                end
                            end
                            s = s .. string.char(tonumber(ch))
                        else
                            error("Unknown escape sequence: " .. c2)
                        end
                        index = index + 2
                    elseif c == "\"" then
                        break
                    else
                        index = index + 1
                        s = s .. c
                    end
                end
                return s
            elseif text:sub(index, index + 3) == "true" then
                index = index + 4
                return true
            elseif text:sub(index, index + 4) == "false" then
            index = index + 5
                return false
            elseif text:sub(index, index + 2) == "nil" then
                index = index + 3
                return nil
            else
                -- number
                local num = ""
                while true do
                    local c = text:sub(index, index)
                    if c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == "" then
                        break
                    else
                        num = num .. c
                        index = index + 1
                    end
                end
                local n2 = tonumber(num)
                if not n2 then
                    error("Unable to read value (" .. num .. ")")
                else
                    return n2
                end
            end
        end
        
        local function readWhitespace()
            local c = text:sub(index, index)
            while true do
                readComment()
                if c == ' ' or c == '\t' or c == '\n' or c == '\r' then
                    index = index + 1
                else
                    break
                end
                if index > text:len() then
                    break
                end
                c = text:sub(index, index)
            end
        end
        
        readWhitespace()
        while text:sub(index, index) ~= "" do
            readWhitespace()
            local line = ""
            while true do
                local c = text:sub(index, index)
                if c == "\r" then
                    index = index + 1
                    if text:sub(index, index) == "\n" then
                        index = index + 1
                    end
                    break
                elseif c == "\n" then
                    index = index + 1
                    break
                elseif c == "" then
                    break
                else
                    line = line .. c
                end
                index = index + 1
            end
            while line:sub(1, 1) == " " or line:sub(1, 1) == "\t" do
                line = line:sub(2) -- strip whitespace
            end
            if line:sub(1, 1) == "." then
                parseControl(line)
            elseif line == "" or line:sub(1, 1) == ";" then
                -- do nothing.
            else
                local op = parseOpcode(line)
                if not op then error"Unable to parse opcode!" end
                op.LineNumber = lineNumber
                --table.insert(func.Instructions, op)
                -- I CAN'T BELIEVE I HAD TO RESORT TO THIS CRAP TO GET IT TO ADD INSTRUCTIONS. I MEAN SERIOUSLY, LUA, COME ON...
                getmetatable(func.Instructions).__newindex(func.Instructions, func.Instructions.Count, op)
            end
            lineNumber = lineNumber + 1
        end
        
        local instr1 = func.Instructions[func.Instructions.Count - 1]
        local instr2 = Instruction:new("RETURN")
        instr2.A = 0
        instr2.B = 1
        instr2.C = 0
        --getmetatable(func.Instructions).__newindex(func.Instructions, func.Instructions.Count, op)
        if instr1 then
            if instr1.Opcode ~= "RETURN" then
                getmetatable(func.Instructions).__newindex(func.Instructions, func.Instructions.Count, instr2)
                --table.insert(func.Instructions, func.Instructions.Count, instr2)
            end
        else
            getmetatable(func.Instructions).__newindex(func.Instructions, 0, instr2)
        end
        return file
    end,
}

if false then -- Testing. 
    local p = Parser:new()
    local file = p:Parse[[
    .const "print"
    .const "Hello"
    getglobal 0 0
    loadk 1 1
    call 0 2 1
    return 0 1
    ]]
    local code = file:Compile()
    local f = io.open("lasm.out", "wb")
    f:write(code)
    f:close()
    local funcX = { loadstring(code) }
    print(funcX[1], funcX[2])
    if funcX[1] then
        funcX[1]()
    end
    --table.foreach(file.Main.Instructions, function(x) pcall(function() print(x) end) end)
    --funcX()
end
