
function clone(object)--clone����
	local lookup_table = {}--�½�table���ڼ�¼
	local function _copy(object)--_copy(object)��������ʵ�ָ���
		if type(object) ~= "table" then
			return object   ---������ݲ���table ֱ�ӷ���object(�������������\�ַ���ֱ�ӷ��ظ�����\���ַ���)
	elseif lookup_table[object] then
		return lookup_table[object]--���������ڵݹ��ʱ���,������table�Ѿ����ƹ���,��ֱ�ӷ���
	end
	local new_table = {}
	lookup_table[object] = new_table--�½�new_table��¼��Ҫ���ƵĶ����ӱ�,���ŵ�lookup_table[object]��.
	for key, value in pairs(object) do
		new_table[_copy(key)] = _copy(value)--����object�͵ݹ�_copy(value)��ÿһ�����е����ݶ����Ƴ���
	end
	return setmetatable(new_table, getmetatable(object))--ÿһ����ɱ�����,�Ͷ�ָ��table����metatable��ֵ
	end
	return _copy(object)--����clone������object��ָ��/��ַ
end
