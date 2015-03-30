
require('dump')
require('clone')

local gl=_G
_G={}

local catch_range={min=0,max=0}

local catch_logic={
	logic=nil,
	position_range=catch_range,
	length_range=catch_range,
	count_range=catch_range,
	children={},
}

local catch_logic={
	logic=nil,
	position_range={max=0,min=0},
	length_range=nil,
	count_range=nil,
	children={},
}

local function create_catch_logic(catcher)
	catcher=catcher or {}
	setmetatable(catcher,{__index=catch_logic})
	return catcher
end

local catch_preset_logic=clone(catch_logic)
catch_preset_logic.length_range={max=1,min=1}
catch_preset_logic.count_range={max=1,min=1}

local function create_preset_catch_logic(catcher)
	catcher=catcher or {}
	setmetatable(catcher,{__index=catch_preset_logic})
	return catcher
end


local catch_content = {
	stuff='',
	cur_pos=0,
	cursor=0,
	cutline=function ( content,pos1,pos2 )
		if(pos1==nil)then
			assert(pos2,'')
			pos1=content.cur_pos
			pos2=content:len()
		elseif(pos2==nil)then
			pos2=content.cur_pos+pos1
			pos1=content.cur_pos
		else
			pos1=pos1+content.cur_pos
			pos2=pos2+content.cur_pos
		end
		return content.stuff:sub(pos1,pos2)
	end,
	at=function (self,index)
		return self.stuff:sub(self.cur_pos+index,self.cur_pos+index)
	end,
	is_end=function (self)
		if(self.cur_pos==self.stuff:len() or self.cursor==self.stuff:len())then
			return true
		else
			return false
		end
	end
}

local catch_param={
	charset=nil,
	content=catch_content,
}

local catch_result={
	line='',
	pos=0,
	count_range=catch_range,
	length_range=catch_range,
	catcher=nil,
	catcher_host=nil,
}

local match_result={
	line='',
	pos=0,
	len=0,
	catcher=nil,
	catcher_host=nil,
	is_matched=true,
}

local function catch_string( catch_body,catch_param )
	local string1 = catch_body.children
	local content = catch_param.content
	local count = 0
	while(true)do
		if(string1~=content:cutline(count*string1:len(),(1+count)*string1:len()))then
			break
		end
		count=count+1
	end

	if(count==0)then
		return nil
	end
	local result={
		line=content:cutline(count*string1:len()),
		pos=0,
		count_range={max=count,min=count},
		length_range={max=count*string1:len(),min=count*string1:len()},
		catcher=catch_body,
		catcher_host=catch_body,
	}
	return result

end

local function create_string_catcher(str1,catcher_name)
	local catcher={
		logic=catch_string,
		children=str1,
		name=catcher_name,
	}
	catcher=create_preset_catch_logic(catcher)
	return catcher
end

local function catch_string_list( catch_body,catch_param )
	local string1
	local content = catch_param.content
	local count = 0

	local catch_word_result
	local word_catcher=create_string_catcher('')
	for k,v in pairs(catch_body.children) do
		string1=v
		word_catcher.children=v
		catch_word_result=word_catcher:logic(catch_param)
		if(catch_word_result)then
			count=catch_word_result.count_range.max
			break
		end
	end

	local result={
		line=content:cutline(count*string1:len()),
		pos=0,
		count_range={max=count,min=count},
		length_range={max=count*string1:len(),min=count*string1:len()},
		catcher=catch_body,
		catcher_host=catch_body,
	}
	return result

end

local function create_word_catcher(string_list,catcher_name)
	local catcher={
		logic=catch_string_list,
		children=(type(string_list)=='string' and {string_list}) or string_list,
		name=catcher_name,
	}
	catcher=create_preset_catch_logic(catcher)
	return catcher
end

local function catch_chars( catch_body,catch_param )
	local chars=catch_body.children
	local content = catch_param.content
	local count = 0
	while(content:at(count+1):len()~=0)do
		if(chars:find('['..content:at(count+1)..']')==nil)then
			break
		end
		count=count+1
	end

	if(count==0)then
		return nil
	end
	local catched=content:at(count+1)
	local result={
		line=content:cutline(count),
		pos=0,
		count_range={max=count,min=count},
		catcher=create_string_catcher(catched,'string(\''..catched..'\') catcher'),
		catcher_host=catch_body,
	}
	result.length_range=result.count_range
	return result

end

local function catch_mixed_range( range1,range2 )
	if(range1==nil or range2==nil)then
		return nil
	end
	if(range1==range2)then
		return clone(range1)
	end
	if(range1.max<range2.min or range2.max<range1.min)then
		return nil
	end
	if(range1.max>range2.max)then
		return {max=range1.max,min=range2.min}
	else
		return {max=range2.max,min=range1.min}
	end
end

local function catch_or( catch_body,catch_param )
	local content = catch_param.content
	local logic_list = catch_body.children
	local result = nil
	local catch_result=nil
	for k,v in pairs(logic_list) do
		result=v.logic(v,catch_param)
		if(result)then
			local line,pos,count_range,length_range=result.line,result.pos,result.count_range,result.length_range
			local mixed_count_range = catch_mixed_range(catch_body.count_range or count_range,count_range)
			local mixed_length_range = catch_mixed_range(catch_body.length_range or length_range,length_range)
			if(mixed_count_range~=nil and mixed_length_range~=nil)then
				catch_result={
					count_range=mixed_count_range,
					length_range=mixed_length_range,
					line=line,
					pos=pos,
					catcher=v,
					catcher_host=catch_body,
				}
				break
			end
		end
	end

	return catch_result
end

local function catch_and( catch_body,catch_param )
	local content = catch_param.content
	local logic_list = catch_body.children
	local result = nil
	local catch_result=nil
	local mixed_count_range=catch_body.count_range
	local mixed_length_range=catch_body.length_range
	for k,v in pairs(logic_list) do
		result=v.logic(v,catch_param)
		if(result)then
			local line,pos,count_range,length_range=result.line,result.pos,result.count_range,result.length_range
			mixed_count_range = catch_mixed_range(mixed_count_range or count_range,count_range)
			mixed_length_range = catch_mixed_range(mixed_length_range or length_range,length_range)
			if(mixed_count_range==nil and mixed_length_range==nil)then
				break
			end
		else
			return nil
		end
	end

	if(mixed_count_range==nil and mixed_length_range==nil)then
		return nil
	end

	catch_result={
		count_range=mixed_count_range,
		length_range=mixed_length_range,
		line=content:cutline(length_range.max),
		pos=catch_body.position_range.min,
		catcher=v,
		catcher_host=catch_body,
	}
	return catch_result
end

local function overlap_string( string1,string2 )
	local overlapped_chars=''
	for s in string1:gfind('['..string2..']') do
		overlapped_chars=overlapped_chars..s
	end
	return overlapped_chars
end

local function find_value_in_table( table1,value )
	for k,v in table1 do
		if(value==v)then
			return k
		end
	end
	return nil
end

local function overlap_table( table1,table2 )
	local table3
	if(#table1>#table2)then
		table3=table1
		table1=table2
		table2=table3
	end

	table3={}
	for k,v in table1 do
		if(find_value_in_table(table2,v))then
			table3[#table3+1]=v
		end
	end

	return table3
end

local function catch_not( catch_body,catch_param )
	catch_param=clone(catch_param)
	local content = catch_param.content
	local logic_list = catch_body.children
	local result = nil
	local catch_result=nil
	local count=0
	local catch_or_result
	local param_stuff_pos = catch_param.content.cur_pos
	while(catch_param.content:is_end()==false)do
		catch_or_result=catch_or(catch_body,catch_param)
		if(catch_or_result)then
			break
		end
		count=count+1
		catch_param.content.cur_pos=param_stuff_pos+count
	end
	catch_param.content.cur_pos=param_stuff_pos

	catch_result={
		count_range={max=count,min=count},
		length_range={max=count,min=count},
		line=content:cutline(count),
		pos=0,
		catcher=catch_or_result.catcher,
		catcher_host=catch_body,
	}
	return catch_result
end

local function catch(catch_body,catch_param)
	local catch_result=catch_body.logic(catch_body,catch_param)
	return catch_result
end

local function match(catch_result)
	local match_result={
		line=catch_result.line,
		pos=catch_result.pos,
		len=catch_result.length_range.max,
		count=catch_result.count_range.max,
		catcher=catch_result.catcher,
		catcher_host=catch_result.catcher_host,

		is_matched=true,
	}

	return match_result
end

local function extend( org,src )
	local metatable=getmetatable(org) or {}
	metatable.__index=src
	setmetatable(org,metatable)
end

local function create_catcher_param(stuff)
	local test_catch_param={
		content={
			stuff=stuff,
		}
	}
	extend(test_catch_param.content,catch_content)
	return test_catch_param
end

local function create_chars_catcher( chars1,catcher_name )
	local catcher={
		logic=catch_chars,
		children=chars1,
		name=catcher_name,
	}
	catcher=create_preset_catch_logic(catcher)

	return catcher
end

local function create_overlap(catch_body_list,catch_param)
	local overlapped_chars
	local overlapped_words
	for k,v in catch_body_list do
		if(type(v.chidren)=='string')then
			overlapped_chars=overlap_string(overlapped_chars or v.children,v.children)
		elseif(type(v.children)=='table')then
			overlapped_words=overlap_table(overlapped_words or v.chidren,v.chidren)
		end
	end

	if(type(overlapped_words)=='table' and #overlapped_words>0 and overlapped_chars:len()>0 )then
		local temp_table={}
		for k,v in pairs(overlapped_words) do
			if(v:gfind('['..overlapped_chars..']')==v)then
				temp_table[#temp_table+1]=v
			end
		end
		overlapped_words=temp_table
	end

	local catcher
	if(type(overlapped_words)=='table' and #overlapped_words>0)then
		catcher = create_string_catcher(overlapped_words)
	elseif(type(overlapped_chars)=='string' and overlapped_chars:len()>0)then
		catcher = create_chars_catcher(overlapped_chars,catch_param)
	end

	return catcher

end

local function create_or_catcher(catcher_list,catcher_name)
	local catcher={
		logic=catch_or,
		children=(catcher_list.logic~=nil and {catcher_list}) or clone(catcher_list),
		length_range=nil,
		count_range=nil,
		name=catcher_name,
	}
	catcher=create_catch_logic(catcher)
	return catcher
end

local function create_and_catcher(catcher_list,catcher_name)
	local catcher={
		logic=catch_and,
		children=clone(catcher_list),
		length_range=nil,
		count_range=nil,
		name=catcher_name,
	}
	catcher=create_catch_logic(catcher)
	return catcher
end

local function create_not_catcher(catcher_list,catcher_name)
	local catcher={
		logic=catch_not,
		children=(catcher_list.logic and {catcher_list}) or clone(catcher_list),
		length_range=nil,
		count_range=nil,
		name=catcher_name,
	}
	catcher=create_catch_logic(catcher)
	return catcher
end

local function catch_skip_to_case( catch_body,catch_param )
	local catch_param= clone(catch_param)
	local catcher = catch_body.children
	local pos,length_range,count_range=catch_body.pos,catch_body.length_range,catch_body.count_range
	local count = pos or 0

	local content = catch_param.content
	local content_pos=catch_param.content.cur_pos
	local case_catch_result
	while((length_range==nil or count<length_range.max) and catch_param.content:is_end()==false)do
		case_catch_result=catcher:logic(catch_param)
		if(case_catch_result)then
			break
		end
		count=count+1
		content.cur_pos=content_pos+count
	end
	content.cur_pos=content_pos

	if(case_catch_result==nil)then
		return nil
	end
	
	catch_result={
		count_range={max=count,min=count},
		length_range={max=count,min=count},
		line=content:cutline(count),
		pos=0,
		catcher=case_catch_result.catcher_host,
		catcher_host=catch_body,
	}
	return catch_result

end

local function create_skip_to_case_catcher(catcher,catcher_name)
	local catcher={
		logic=catch_skip_to_case,
		children=catcher,
		length_range=nil,
		count_range=nil,
		name=catcher_name,
	}
	catcher=create_catch_logic(catcher)
	return catcher
end

local function test_all()

	local function test_string( ... )
		-- body
		local test_catch_param = create_catcher_param('hello(dsfd,lkwe)')

		local test_catcher=create_string_catcher('hello','string catcher')

		local result=test_catcher:logic(test_catch_param)
		vdump(result)

		return result

	end

	local function test_chars()
		-- body
		local test_catch_param = create_catcher_param('hello(dsfd,lkwe)')

		local test_catcher=create_chars_catcher('abhel','chars catcher')

		local result=test_catcher:logic(test_catch_param)
		vdump(result)

		return result

	end

	local function test_or(  )
		local test_catch_param = create_catcher_param('hello(dsfd,lkwe)')

		local test_catcher_string=create_string_catcher('hello','string catcher')
		local test_catcher_chars=create_chars_catcher('lhed(o','chars catcher')
		local test_catcher_or
		local result
		test_catcher_or=create_or_catcher({test_catcher_string,test_catcher_chars},'catch string first')
		result = test_catcher_or:logic(test_catch_param)
		vdump(result)
		local result1=result
		test_catcher_or=create_or_catcher({test_catcher_chars,test_catcher_string,},'catch chars first')
		result = test_catcher_or:logic(test_catch_param)
		vdump(result)
		return result1,result

	end

	local function test_and(  )
		local test_catch_param = create_catcher_param('hello(dsfd,lkwe)')

		local test_catcher_string=create_string_catcher('hello','string catcher')
		local test_catcher_chars=create_chars_catcher('lhed(o','chars catcher')
		local test_catcher_and
		local result
		test_catcher_and=create_and_catcher({test_catcher_string,test_catcher_chars},'catch string first')
		result = test_catcher_and:logic(test_catch_param)
		vdump(result)
		local result1=result
		test_catcher_and=create_and_catcher({test_catcher_chars,test_catcher_string,},'catch chars first')
		result = test_catcher_and:logic(test_catch_param)
		vdump(result)
		return result1,result

	end

	local function test_not(  )
		local test_catch_param = create_catcher_param('hello(dsfd,lkwe)')

		local test_catcher_string=create_string_catcher('hello','string catcher')
		local test_catcher_chars=create_chars_catcher('lhed(o','chars catcher')
		local test_catcher_not
		local result
		test_catcher_not=create_not_catcher({test_catcher_string,test_catcher_chars},'catch string first')
		result = test_catcher_not:logic(test_catch_param)
		vdump(result)
		local result1=result
		test_catcher_not=create_not_catcher({test_catcher_chars,test_catcher_string,},'catch chars first')
		result = test_catcher_not:logic(test_catch_param)
		vdump(result)
		return result1,result

	end

	local function test_match(  )
		--vdump(match(test_string()))
		--vdump(match(test_chars()))
		table.foreach({test_or()},function(_,x)vdump(match(x))end)
		local test_catcher_string=create_string_catcher('hello','word catcher')

	end

	local function test_catch_word()
		local test_catch_param = create_catcher_param('hello(dsfd,lkwe)')
		local test_catcher_word=create_word_catcher('hello','string catcher')
		local result
		result=test_catcher_word:logic(test_catch_param)
		vdump(result)

		test_catcher_word=create_word_catcher({'haha','hello','kljl'},'word list catcher')
		result=test_catcher_word:logic(test_catch_param)
		vdump(result)

		test_catcher_word=create_word_catcher({'hell','haha','hello','kljl'},'word list catcher')
		result=test_catcher_word:logic(test_catch_param)
		vdump(result)

	end

	local function test_catch_not(  )
		local test_catch_param = create_catcher_param('helloklkjw')
		local test_catcher_chars = create_chars_catcher('l')
		local test_catcher_not = create_not_catcher(test_catcher_chars,'not catcher')
		local result = test_catcher_not:logic(test_catch_param)
		vdump(result)
	end

	local function test_catch_skip_to_case(  )
		local test_catch_param = create_catcher_param('helloklkjw')
		local case_list={'','h','e','l','o','w','j','r','rs','rl'}
		local result
		for k,v in ipairs(case_list) do
			local test_catcher_chars = create_chars_catcher(v)
			local test_catcher_skip_to_case = create_skip_to_case_catcher(test_catcher_chars,'skip to case catcher')
			result = test_catcher_skip_to_case:logic(test_catch_param)
			vdump(result)
		end
	end

	--test_string()
	--test_chars()
	--test_or()
	--test_match()
	--	test_and()
	--	test_not()
	--	test_catch_word()
	--test_catch_not()
	test_catch_skip_to_case()

end

test_all()

local catcher_creater={
	create_catcher_param=create_catcher_param,
	create_word_catcher=create_word_catcher,
	create_string_catcher=create_string_catcher,
	create_chars_catcher=create_chars_catcher,
	create_or_catcher=create_or_catcher,
	create_not_catcher=create_not_catcher,
	create_skip_to_case_catcher=create_skip_to_case_catcher,
}

return catcher_creater
