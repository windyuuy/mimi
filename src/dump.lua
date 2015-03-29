--- @brief 调试时打印变量的值
--- @param data 要打印的字符串
--- @param [max_level] table要展开打印的计数，默认nil表示全部展开
--- @param [prefix] 用于在递归时传递缩进，该参数不供用户使用于
--- @ref http://dearymz.blog.163.com/blog/static/205657420089251655186/
function var_dump(data, max_level, prefix)
	assert(var_dump~=print,'')
	if type(prefix) ~= "string" then
		prefix = ""
	end
	if type(data) ~= "table" then
		print(prefix .. tostring(data))
	else
		print(data)
		if max_level ~= 0 then
			local prefix_next = prefix .. "    "
			print(prefix .. "{")
			for k,v in pairs(data) do
				io.stdout:write(prefix_next .. k .. " = ")
				if type(v) ~= "table" or (type(max_level) == "number" and max_level <= 1) then
					print(v)
				else
					if max_level == nil then
						var_dump(v, nil, prefix_next)
					else
						var_dump(v, max_level - 1, prefix_next)
					end
				end
			end
			print(prefix .. "}")
		end
	end
end

function vdump(data, max_level)
	var_dump(data, max_level or 5)
end
