-- 定义
function myFunction(param1, param2)
    print(param1, param2)
end

myFunction("hello", "world")

local MyTable = {}
-- 定义（注意第一个参数是 self）
function MyTable:myFunction(param1, param2)
    print(self, param1, param2)
end

-- 当函数定义中使用的是冒号, 意味着会将MyTable本身传入到函数第一个参数
MyTable:myFunction("hello", "world")

MyTable.myFunction("hello", "world")



-- 定义
function MyTable.aFunction(param1, param2)
    print(self, param1, param2)
end

MyTable.aFunction("hello", "world")

MyTable:aFunction("hello", "world")