
local strlib=require('strlib_ext')

local catcher=require('catcher')

local function mark(info)

end

local function test_mark()
	local f=io.input('F:/SOFTS/MyCreate/mimi_parser/src/lua_fmt.mimi')
	for line in f:lines() do
		print(line)
	end

end

local function test_swap()

end

local function test_all()
	test_mark()
	test_swap()
end

test_all()
