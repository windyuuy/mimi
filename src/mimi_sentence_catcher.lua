
local catcher=require('catcher')

local function mark(info)
	
end

local function test_mark()
	local case={
		'mark $letter as combination of \'abc\'',
		'mark $word as some of $letter',
		'mark $div as combination of \'\\\s\'',
		'mark $any_div as any of $div',
	}
end

local function test_swap()
	
end

local function test_all()
	test_mark()
	test_swap()
end


