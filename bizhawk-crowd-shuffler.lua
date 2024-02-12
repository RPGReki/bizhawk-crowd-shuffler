local config = {}

config.sessionPath = os.getenv("session") and os.getenv("session") or 'default'

local pathseparator = package.config:sub(1,1)
config.gamePath = "." .. pathseparator .. "sessions" .. pathseparator .. config.sessionPath .. pathseparator .. "CurrentROMs" .. pathseparator

local frame = 0

local frame_check_mod = 10 -- check every X frames

local function isempty(s)
  return s == nil or s == ''
end

local commands = {}

function commands.switchRom(rom)
    local currentGame = userdata.get("currentGame")

    print("DEBUG: switchRom=" .. rom)
    
    if(currentGame) then
        savestate.saveslot(9, true)
    end

    local nextGame = rom

    client.openrom(config.gamePath .. nextGame)
    savestate.loadslot(9, true)

    userdata.set("currentGame", nextGame)
end

function commands.ping()
    -- print("DEBUG: heartbeat received")
    comm.socketServerSend("pong");
end

local function parseAndExecuteResponse(response)
    for line in string.gmatch(response, "([^\n]+)") do
        local t={}

        for str in string.gmatch(line, "([^\t]+)") do
            table.insert(t, str)
        end

        local input = {
            command = t[1],
            args = t[2]
        }

        -- print("DEBUG: command=" .. input.command)

        local command = commands[input.command]

        if(command) then
            commands[input.command](input.args)
        end
    end
end

local function main()
   -- purge socket data
   comm.socketServerSetTimeout(14)
   comm.socketServerResponse()

   while true do -- The main cycle that causes the emulator to advance and trigger a game switch.
        frame = frame + 1

        if (frame % frame_check_mod) == 0 then
            frame = 0
            local response = comm.socketServerResponse()

            if isempty(response) == false then
                parseAndExecuteResponse(response)
            end
        end
        emu.frameadvance()
    end

    print("loaded, checking every " .. frame_check_mod .. " frames")
end

if emu then
    main()
else
    print("Running tests") 
    -- run tests
    comm = {}

    local function test_ping()
        local called = false
        comm.socketServerSend = function()
            called = true
        end

        commands.ping()

        assert(called)
    end

    local function test_parseAndExecuteResponse()
        local called = false
        commands.test = function()
            called = true
        end

        assert(called == false)

        parseAndExecuteResponse("test")

        assert(called)
    end

    local function test_parseAndExecuteResponse_withArgs()
        local called = false
        local args
        commands.test = function(input)
            called = true
            args = input
        end

        assert(called == false)

        parseAndExecuteResponse("test\tfoo")

        assert(called)

        assert(args == "foo")
    end

    local function test_parseAndExecuteResponse_withMultipleCommands()
        local called = 0
        commands.test = function(input)
            called = called + 1
        end

        assert(called == 0)

        parseAndExecuteResponse("test\ntest\n")

        assert(called == 2)
    end

    local function test_switchRom()
        userdata = {}
        savestate = {}
        client = {}

        client.openrom = function(args)
            client.openrom__args = args
        end

        savestate.loadslot = function(slot, suppress_message)
            savestate.load__slot = slot
            savestate.load__suppress_message = suppress_message
        end

        savestate.saveslot = function(slot, suppress_message)
            savestate.save__slot = slot
            savestate.save__suppress_message = suppress_message
        end

        userdata.get = function()
            return "foo.nes"
        end

        userdata.set = function(key, value)
            userdata.set__value = value
        end

        commands.switchRom("bar.nes")

        assert(savestate.save__slot == 9)
        assert(savestate.save__suppress_message == true)
        assert(client.openrom__args == config.gamePath .. "bar.nes")
        assert(userdata.set__value == "bar.nes")
        assert(savestate.load__slot == 9)
        assert(savestate.load__suppress_message == true)
    end

    test_ping()
    test_parseAndExecuteResponse()
    test_parseAndExecuteResponse_withArgs()
    test_parseAndExecuteResponse_withMultipleCommands()
    test_switchRom();
end
