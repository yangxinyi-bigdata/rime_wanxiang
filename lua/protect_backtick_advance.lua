-- lua/protect_backtick_advance.lua
-- 设置通知消息select_notifier,当触发选词通知时,首先打印一下消息,看看都有什么内容.

local function protect_backtick(key_event, env)
  local engine = env.engine
  local context = engine.context
  
  -- 只在有候选菜单时处理
  if not context:has_menu() then
    return 2  -- kNoop
  end
  
  local keycode = key_event.keycode
  -- 检查是否是选词键（数字键1-9或空格）
  if (keycode >= 0x31 and keycode <= 0x39) or keycode == 0x20 then
    local input = context.input
    
    -- 检查输入中是否包含反引号
    local backtick_pos = input:find("`")
    if backtick_pos then
      -- 获取当前段信息
      local composition = context.composition
      if composition:empty() then
        return 2
      end
      
      local seg = composition:back()
      local selected_index = keycode == 0x20 and 0 or (keycode - 0x31)
      local cand = seg:get_candidate_at(selected_index)
      
      if cand and cand.end_ == backtick_pos - 1 then
        -- 候选词正好在反引号之前结束，反引号会被自动提交
        -- 我们需要阻止这个行为
        
        -- 保存当前状态
        local saved_input = input:sub(backtick_pos)  -- 从反引号开始的部分
        
        -- 手动提交候选词文本
        engine:commit_text(cand.text)
        
        -- 清空当前输入
        context:clear()
        
        -- 重新输入从反引号开始的部分
        context:push_input(saved_input)
        
        return 1  -- kAccepted
      end
    end
  end
  
  return 2  -- kNoop
end

return protect_backtick