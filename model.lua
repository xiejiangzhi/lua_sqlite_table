local M = {}
M.__index = M

local SQLChain = {}
SQLChain.__index = SQLChain

local sqlite3 = require 'sqlite3'

local function toSqlVal(val)
  if type(val) == 'string' then
    return "'" .. val .. "'"
  else  -- boolean number
    return tostring(val)
  end
end

local function toKeyValStr(table, split)
  local cond = ''
  if split == nil then split = ', ' end
  for k, v in pairs(table) do
    if cond ~= '' then cond = cond .. split end
    cond = cond .. k .. ' = ' .. toSqlVal(v)
  end
  return cond
end

------------------- SQLChain ------------------------

function SQLChain.new(model)
  local obj = {}
  setmetatable(obj, SQLChain)

  obj.model = model

  obj.conditions = {}
  obj.sql_select = '*'
  obj.sql_limit = nil
  obj.sql_order = nil

  return obj
end

function SQLChain:select(s)
  self.sql_select = s
  return self
end

function SQLChain:where(cond)
  local cond_sql = ''
  if type(cond) == 'table' then
    table.insert(self.conditions, toKeyValStr(cond, ' AND '))
  else
    table.insert(self.conditions, cond)
  end
  return self
end

function SQLChain:limit(n)
  self.sql_limit = n
  return self
end

function SQLChain:order(order)
  self.sql_order = order
  return self
end

function SQLChain:to_sql()
  local sql = 'SELECT ' .. self.sql_select .. ' FROM ' .. self.model.table_name .. ' WHERE '
  local conds = ''

  for i, v in ipairs(self.conditions) do
    if i ~= 1 then conds = conds .. ' AND ' end
    conds = conds .. '(' .. v .. ')'
  end
  sql = sql .. conds
  if self.sql_order then sql = sql .. ' ORDER BY ' .. self.sql_order end
  if self.sql_limit then sql = sql .. ' LIMIT ' .. self.sql_limit end

  return sql
end

function SQLChain:first()
  local t = self.model:exec(self:to_sql())
  return self.model:toRowTable(t)
end

function SQLChain:count()
  self.sql_select = "count(*)"
  local t = self.model:exec(self:to_sql())
  return t[1][1]
end

function SQLChain:to_a()
  local t = self.model:exec(self:to_sql())
  if t == nil then return {} end
  return self.model:toRowsTable(t)
end

------------------- Model ------------------------

function M.new(table_name, schema, db)
  local obj = {}
  setmetatable(obj, M)

  M.conn = M.conn or sqlite3.open(db or '')
  M.conn:exec(schema)

  obj.table_name = table_name
  obj.table_info = M.conn:exec("PRAGMA table_info(" .. table_name .. ")")
  obj.columns = obj.table_info[2]
  return obj
end

function M:find(val)
  local sql = 'SELECT * FROM ' .. self.table_name .. ' WHERE ' .. self.columns[1] .. ' = ' .. toSqlVal(val)
    .. ' LIMIT 1'
  local t = self:exec(sql)
  if t == nil then return end
  return self:toRowTable(t)
end

function M:create(attrs)
  local sql = 'INSERT INTO ' .. self.table_name .. '('
  local vals = '('
  for k, v in pairs(attrs) do
    if vals == '(' then
      sql = sql .. k
      vals = vals .. toSqlVal(v)
    else
      sql = sql .. ', ' .. k
      vals = vals .. ', ' .. toSqlVal(v)
    end
  end
  sql = sql .. ') VALUES' .. vals .. ')'

  local t = self:exec(sql .. '; SELECT last_insert_rowid() as id;')
  return tonumber(t.id[1])
end

function M:update(id_or_cond, attrs)
  local sql = 'UPDATE ' .. self.table_name
  sql = sql .. ' SET ' .. toKeyValStr(attrs, ',')
  if type(id_or_cond) == 'table' then
    sql = sql .. ' WHERE ' .. toKeyValStr(id_or_cond)
  else
    sql = sql .. ' WHERE ' .. self.columns[1] .. ' = ' .. toSqlVal(id_or_cond)
  end
  return self:exec(sql)
end

function M:delete(id_or_cond)
  local sql = "DELETE FROM " .. self.table_name
  if type(id_or_cond) == 'table' then
    sql = sql .. ' WHERE ' .. toKeyValStr(id_or_cond)
  else
    sql = sql .. ' WHERE ' .. self.columns[1] .. ' = ' .. toSqlVal(id_or_cond)
  end
  return self:exec(sql)
end

function M:where(cond)
  return SQLChain.new(self):where(cond)
end

function M:exec(sql)
  return M.conn:exec(sql)
end

function M:toRowTable(r)
  local t = {}
  for i, k in ipairs(r[0]) do
    t[k] = r[k][1]
  end
  return t
end

function M:toRowsTable(r)
  local rows = {}
  for i = 1, #r[1] do
    local t = {}
    for j, k in ipairs(r[0]) do t[k] = r[k][i] end
    table.insert(rows, t)
  end
  return rows
end

return M
