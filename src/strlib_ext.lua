
local function split_str(str1,sign)
	local lines = {}
	local i = 0
	local j=0
	while i do
		i = string.find(str1, sign, i+1)   -- find 'next' newline
		table.insert(lines,str1:sub(j+1,i and i-1))
		j=i
	end
	return lines
end

local strlib_ext={
	split_str=split_str,
}

local function test_all()
	local function test_split()
		local lines=split_str('lkjlj,lwkjel,lwekf,lwkef',',')
		for k,v in pairs(lines) do
			print(k,v)
		end
	end

	test_split()
end

test_all()

return strlib_ext
