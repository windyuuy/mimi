
local strlib=require('strlib_ext')

local catcher=require('catcher')

local catchers_definitions={}

local function create_info(line)
	local info={
		fullline=line,
		head=line:gmatch('(%w+)')(),
		body=line:gmatch(' (.+)')(),
	}
	return info

end

local function split_element(collection)
	local signset={}
	local rep=collection:gmatch('[^(\\,),]+')
	local exchMap={['\\,']=','}
	for v in rep do
		signset[#signset+1]=exchMap[v] or v
	end
	return signset
end

local func_map={
	combination=function(info)
		local collection=info.collection
		local signset=split_element(collection)
		local collection=table.concat(signset,'')
		info.signset=signset
		info.collection=collection
		
		local chars_catcher=catcher.create_chars_catcher(info.collection,info.head)
		catchers_definitions[info.newdef]=chars_catcher
	end,

}

function func_map.none(parameters)
	
end

function func_map.some(info)
	
end

function func_map.any(info)
	
end

local function mark(info)
	local line=info.fullline
	local rep=line:gmatch('($%w+)')
	info.newdef=rep()
	rep=line:gmatch('(%w+)')
	rep()
	rep()
	assert('as'==rep(),'')
	info.relative=rep()
	assert('of'==rep(),'')
	local pos=line:find('of',('mark $*'):len())
	assert(pos,'')
	info.collection=line:sub(pos+3)
	func_map[info.relative](info)
end

local function test_mark()
	local f=io.input('F:/SOFTS/MyCreate/mimi_parser/src/lua_fmt.mimi')
	for line in f:lines() do
		print(line)
		local info=create_info(line)
		mark(info)
	end

end

local function test_swap()

end

local function test_all()
	test_mark()
	test_swap()
end

test_all()
