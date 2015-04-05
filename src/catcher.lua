
require('dump')
require('clone')

local gl=_G
_G={}

local catch_range={min=0,max=0}

local catch_logic={
	name=nil,
	logic=nil,
	children={},
}

local function create_catch_logic(catcher)
	catcher=catcher or {}
	setmetatable(catcher,{__index=catch_logic})
	return catcher
end

local create_preset_catch_logic=create_catch_logic

local catch_content = {
	stuff='',
	cur_pos=0,
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
	end,
	getCurPos=function (self)
		return self.cur_pos
	end
}

local catch_param={
	charset=nil,
	content=catch_content,
}

local catch_result={
	line='',
	pos=0,
	length=0,
	catcher=nil,
	catcher_host=nil,
}

local function catch_string( catch_body,catch_param )
	local string1 = catch_body.children
	local content = catch_param.content
	if(string1~=content:cutline(1,string1:len()))then
		return nil
	end

	local result={
		line=string1,
		pos=content:getCurPos(),
		length=string1:len(),
		catcher=catch_body,
		catcher_host=catch_body,
	}
	return result

end

local function create_string_catcher(str1,catcher_name)
	local catcher={
		logic=catch_string,
		logic_name='catch_string',
		children=str1,
		name=catcher_name,
	}
	catcher=create_catch_logic(catcher)
	return catcher
end

local function catch_string_list( catch_body,catch_param )
	local string1
	local content = catch_param.content
	local count = 0

	local catch_word_result
	local string_catcher=create_string_catcher('')
	for k,v in pairs(catch_body.children) do
		string1=v
		string_catcher.children=v
		catch_word_result=string_catcher:logic(catch_param)
		if(catch_word_result)then
			break
		end
	end

	catch_word_result.catcher=catch_body
	catch_word_result.catcher_host=catch_body
	return catch_word_result

end

local function create_string_catcher(string_list,catcher_name)
	local catcher={
		logic=catch_string,
		logic_name='catch_string',
		children=string_list,
		name=catcher_name,
	}
	catcher=create_preset_catch_logic(catcher)
	return catcher
end

local function create_string_list_catcher(string_list,catcher_name)
	local catcher={
		name=catcher_name,
		children=(type(string_list)=='string' and {string_list}) or string_list,
		logic=catch_string_list,
		logic_name='catch_string_list',
	}
	create_catch_logic(catcher)
	return catcher
end

local function catch_chars( catch_body,catch_param )
	local chars=catch_body.children
	local content = catch_param.content
	if(chars:find('['..content:at(1)..']')==nil)then
		return nil
	end

	local result={
		line=content:at(1),
		pos=content:getCurPos(),
		length=1,
		catcher=catch_body,
		catcher_host=catch_body,
	}
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
			local line,pos,length=result.line,result.pos,result.length
			--			local mixed_count_range = catch_mixed_range(catch_body.count_range or count_range,count_range)
			--			local mixed_length_range = catch_mixed_range(catch_body.length_range or length_range,length_range)
			--			if(mixed_count_range~=nil and mixed_length_range~=nil)then
			catch_result={
				length=length,
				line=line,
				pos=pos,
				catcher=v,
				catcher_host=catch_body,
			}
			break
			--			end
		end
	end

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
	local content=catch_param.content
	local children=catch_body.children
	local result=children:logic(catch_param)

	if(result)then
		return nil
	end

	catch_result={
		length=1,
		line=content:at(1),
		pos=content:getCurPos(),
		catcher=catch_body,
		catcher_host=catch_body,
	}
	return catch_result
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
		logic_name='catch_chars',
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
		logic_name='catch_or',
		children=(catcher_list.logic~=nil and {catcher_list}) or clone(catcher_list),
		name=catcher_name,
	}
	catcher=create_catch_logic(catcher)
	return catcher
end

local function create_not_catcher(catcher,catcher_name)
	local catcher={
		logic=catch_not,
		logic_name='catch_not',
		children=catcher,
		name=catcher_name,
	}
	catcher=create_catch_logic(catcher)
	return catcher
end

local catch_not_list=catch_not

local function create_not_list_catcher(catcher_list,catcher_name)
	local catcher=create_not_catcher(create_or_catcher(catcher_list,'not catcher'),catcher_name)
	catcher.logic=catch_not_list
	catcher.logic_name='catch_not_list'
	return catcher
end

local function catch_repeat_times(catch_body,catch_params,maxcount)
	local catch_result={}
	local count=0
	local cought_length=0
	local children=catch_body.children
	local content=catch_params.content
	local catch_params_pos=content.cur_pos

	while(maxcount==nil or count<maxcount)do
		catch_result=children:logic(catch_params)
		if(catch_result==nil)then
			break
		end
		content.cur_pos=content.cur_pos+catch_result.length
		cought_length=cought_length+catch_result.length
		count=count+1
	end

	--	content.cur_pos=content.cur_pos-cought_length
	content.cur_pos=catch_params_pos
	local result={
		length=cought_length,
		count=count,
		line=content:cutline(1,cought_length),
		pos=content:getCurPos(),
		catcher=children,
		catcher_host=catch_body,
		is_catched=(count==maxcount),
	}

	return result
end

local function create_repeat_times_catcher(catcher,catcher_name)
	local catcher={
		logic=catch_repeat_times,
		logic_name='repeat_times_catch',
		children=catcher,
		name=catcher_name,
	}
	catcher=create_catch_logic(catcher)
	return catcher
end

local function catch_count_range(catcher,catch_params,count_range)
	local just_over_range=(count_range.max and count_range.max+1) or nil
	local result=catch_repeat_times(catcher,catch_params,just_over_range)
	if(result.is_catched==true or (count_range.min~=nil and result.count<count_range.min))then
		return nil
	end
	local catch_result=clone(result)
	catch_result.is_catched=true
	return catch_result
end

local function create_count_range_catcher(catcher,catcher_name)
	local catcher={
		logic=catch_count_range,
		logic_name='count_catch',
		children=catcher,
		name=catcher_name,
	}
	catcher=create_catch_logic(catcher)
	return catcher
end

local function test_all()
	local function show_start_tip(tip)
		print('test '..tip..' start')
	end

	local function show_end_tip(tip)
		print('test '..tip..' end')
	end

	local function test_string( ... )
		-- body

		local test_catch_param = create_catcher_param('hello(dsfd,lkwe)')

		local test_catcher=create_string_catcher('hello','string catcher')

		local result=test_catcher:logic(test_catch_param)
		vdump(result)
		assert(result.length==5 and result.pos==0 and result.catcher.logic==catch_string and result.catcher.logic_name=='catch_string','')

		return result

	end

	local function test_chars()
		-- body

		local test_catch_param = create_catcher_param('hello(dsfd,lkwe)')

		local test_catcher=create_chars_catcher('abhel','chars catcher')

		local result=test_catcher:logic(test_catch_param)
		vdump(result)
		assert(result.length==1 and result.pos==0 and result.catcher.logic==catch_chars and result.catcher.logic_name=='catch_chars','')

		return result

	end

	local function test_or()

		local test_catch_param = create_catcher_param('hello(dsfd,lkwe)')

		local test_catcher_string=create_string_catcher('hello','string catcher')
		local test_catcher_chars=create_chars_catcher('lhed(o','chars catcher')
		local test_catcher_or
		local result
		test_catcher_or=create_or_catcher({test_catcher_string,test_catcher_chars},'catch string first')
		result = test_catcher_or:logic(test_catch_param)
		vdump(result)
		assert(result.length==5 and result.pos==0 and result.catcher.logic==catch_string and result.catcher.logic_name=='catch_string','')

		local result1=result
		test_catcher_or=create_or_catcher({test_catcher_chars,test_catcher_string,},'catch chars first')
		result = test_catcher_or:logic(test_catch_param)
		vdump(result)
		assert(result.length==1 and result.pos==0 and result.catcher.logic==catch_chars and result.catcher.logic_name=='catch_chars','')

		return result1,result

	end

	local function test_not()

		local test_catch_param = create_catcher_param('hello(dsfd,lkwe)')

		local test_catcher_string=create_string_catcher('hello','string catcher')
		local test_catcher_string2=create_string_catcher('lhello','string catcher2')
		local test_catcher_chars=create_chars_catcher('lhed(o','chars catcher')
		local test_catcher_not
		local result
		test_catcher_not=create_not_catcher(create_or_catcher({test_catcher_string,test_catcher_chars}),'catch string first')
		result = test_catcher_not:logic(test_catch_param)
		vdump(result)
		assert(result==nil,'')

		local result1=result
		test_catcher_not=create_not_catcher(create_or_catcher({test_catcher_chars,test_catcher_string,}),'catch chars first')
		result = test_catcher_not:logic(test_catch_param)
		vdump(result)
		assert(result==nil,'')

		test_catcher_not=create_not_catcher(create_or_catcher({test_catcher_string2,}),'catch chars first')
		result = test_catcher_not:logic(test_catch_param)
		vdump(result)
		assert(result.length==1 and result.pos==0 and result.catcher.logic==catch_not and result.catcher.logic_name=='catch_not','')

	end

	local function test_not_list()

		local test_catch_param = create_catcher_param('hello(dsfd,lkwe)')

		local test_catcher_string=create_string_catcher('hello','string catcher')
		local test_catcher_string2=create_string_catcher('lhello','string catcher2')
		local test_catcher_chars=create_chars_catcher('lhed(o','chars catcher')
		local test_catcher_not
		local result
		test_catcher_not=create_not_list_catcher({test_catcher_string,test_catcher_chars},'catch string first')
		result = test_catcher_not:logic(test_catch_param)
		vdump(result)
		assert(result==nil,'')

		local result1=result
		test_catcher_not=create_not_list_catcher({test_catcher_chars,test_catcher_string,},'catch chars first')
		result = test_catcher_not:logic(test_catch_param)
		vdump(result)
		assert(result==nil,'')

		test_catcher_not=create_not_list_catcher({test_catcher_string2,},'catch chars first')
		result = test_catcher_not:logic(test_catch_param)
		vdump(result)
		assert(result.length==1 and result.pos==0 and result.catcher.logic==catch_not_list and result.catcher.logic_name=='catch_not_list','')

	end

	local function test_catch_string_list()

		local test_catch_param = create_catcher_param('hello(dsfd,lkwe)')
		local test_catcher_string_list=create_string_list_catcher('hello','string catcher')
		local result
		result=test_catcher_string_list:logic(test_catch_param)
		vdump(result)
		assert(result.length==5 and result.pos==0 and result.catcher.logic==catch_string_list and result.catcher.logic_name=='catch_string_list','')

		test_catcher_string_list=create_string_list_catcher({'haha','hello','kljl'},'word list catcher')
		result=test_catcher_string_list:logic(test_catch_param)
		vdump(result)
		assert(result.length==5 and result.pos==0 and result.catcher.logic==catch_string_list and result.catcher.logic_name=='catch_string_list','')

		test_catcher_string_list=create_string_list_catcher({'hell','haha','hello','kljl'},'word list catcher')
		result=test_catcher_string_list:logic(test_catch_param)
		vdump(result)
		assert(result.length==4 and result.pos==0 and result.catcher.logic==catch_string_list and result.catcher.logic_name=='catch_string_list','')

		return result

	end

	local function test_catch_not()

		local test_catch_param = create_catcher_param('helloklkjw')
		local case_list={'','h','e','l','o','w','j','r','rs','rl'}
		for k,v in ipairs(case_list) do
			local test_catcher_chars = create_chars_catcher(v)
			local test_catcher_not = create_not_catcher(test_catcher_chars,'not catcher')
			local result = test_catcher_not:logic(test_catch_param)
			vdump(result)
		end

	end

	local function test_catch_repeat_times()
		local test_catch_param = create_catcher_param('helloklkjw')
		local case_list={'','h','e','l','o','w','j','r','rs','rl','helo'}
		local times_cases={0,1,2,3,4,5,6,nil,}
		for k,v in ipairs(case_list) do
			for _,i in pairs(times_cases) do
				print('test repeat time ',i)
				local test_catcher_chars = create_chars_catcher(v)
				local test_catcher_repeat = create_repeat_times_catcher(test_catcher_chars,'repeat times catcher')
				local result = test_catcher_repeat:logic(test_catch_param,i)
				vdump(result)
			end
		end
	end

	local function test_catch_count_range()
		local test_catch_param = create_catcher_param('helloklkjw')
		local case_list={'','h','e','l','o','w','j','r','rs','rl','helo'}
		local times_cases={0,1,2,3,4,5,6,nil,}
		for k,v in ipairs(case_list) do
			for _,max in pairs(times_cases) do
				for min=0,max do
					print('test catch range ','min=',min,'max=',max)
					local test_catcher_chars = create_chars_catcher(v)
					local test_catcher_count_range = create_count_range_catcher(test_catcher_chars,'count range catcher')
					local result = test_catcher_count_range:logic(test_catch_param,{min=min,max=max})
					vdump(result)
				end
			end
		end
	end

	local test_list={
		test_string=test_string,
		test_chars=test_chars,
		test_or=test_or,
		test_not=test_not,
		test_not_list=test_not_list,
		test_catch_string_list=test_catch_string_list,
		test_catch_not=test_catch_not,
		test_catch_repeat_times=test_catch_repeat_times,
		test_catch_count_range=test_catch_count_range,
	}

	show_start_tip('test_all')
	for k,v in pairs(test_list) do
		show_start_tip(k)
		v()
		show_end_tip(k)
	end
	show_end_tip('test_all')

end

--test_all()

local catcher_creater={
	create_catcher_param=create_catcher_param,
	create_string_catcher=create_string_catcher,
	create_string_list_catcher=create_string_list_catcher,
	create_chars_catcher=create_chars_catcher,
	create_or_catcher=create_or_catcher,
	create_not_catcher=create_not_catcher,
	create_count_range_catcher=create_count_range_catcher,
}

return catcher_creater
