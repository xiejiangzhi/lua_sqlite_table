local M = {}
M.__index = M

function M.new(...)
  local obj = setmetatable({}, M)
  obj:init(...)
  return obj
end

local SQLChain = {}
SQLChain.__index = SQLChain


local function toSqlVal(val)
  if type(val) == 'string' then
    return "'" .. val:gsub("'", "''") .. "'"
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
  obj:reset()

  return obj
end

function SQLChain:select(s)
  self.sql_select = s
  return self
end

function SQLChain:where(cond, ...)
  local cond_sql = ''
  if type(cond) == 'table' then
    table.insert(self.conditions, toKeyValStr(cond, ' AND '))
  else
    local t = {...}
    cond = cond:gsub('?', function(s) return toSqlVal(table.remove(t, 1)) end)
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
  local sql = 'SELECT ' .. self.sql_select .. ' FROM ' .. self.model.table_name
  local conds = ''

  for i, v in ipairs(self.conditions) do
    if i ~= 1 then conds = conds .. ' AND ' end
    conds = conds .. '(' .. v .. ')'
  end
  if conds ~= '' then sql = sql .. ' WHERE ' .. conds end
  if self.sql_order then sql = sql .. ' ORDER BY ' .. self.sql_order end
  if self.sql_limit then sql = sql .. ' LIMIT ' .. self.sql_limit end

  return sql
end

function SQLChain:reset()
  self.conditions = {}
  self.sql_select = '*'
  self.sql_limit = nil
  self.sql_order = nil
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

--[[

db: default is a new :memory: db
table_schema: string or table.
  "id INTEGER PRIMARY KEY, val INTEGER NOT NULL"
  or { { "id" "INTEGER" "PRIMARY KEY" }, { "val", "INTEGER", "NOT NULL" }, ... }
table_index:
  { { 'xxx_index', { 'col1', 'col2', ...' }, unique = true }, ... }
]]
function M:init(db, table_name, table_schema, table_index)
  self.db = db or require('sqlite3').open(db or ':memory:')

  self:_create_table(table_name, table_schema)
  if table_index then
    self:_create_table_index(table_name, table_index)
  end

  self.table_name = table_name
  local table_raw_info = self.db:exec("PRAGMA table_info(" .. table_name .. ")")

  self.table_info, self.primary_key = M._parse_table_info(table_raw_info)
end

-- find by parimary key
function M:find(val)
  local sql = 'SELECT * FROM '..self.table_name..' WHERE '..self.primary_key..' = '..toSqlVal(val)..' LIMIT 1'
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
  local sql = 'UPDATE '..self.table_name..' SET '..toKeyValStr(attrs, ',')
  if type(id_or_cond) == 'table' then
    sql = sql .. ' WHERE ' .. toKeyValStr(id_or_cond)
  else
    sql = sql .. ' WHERE ' .. self.primary_key .. ' = ' .. toSqlVal(id_or_cond)
  end
  return self:exec(sql)
end

function M:delete(id_or_cond)
  local sql = "DELETE FROM " .. self.table_name
  if type(id_or_cond) == 'table' then
    sql = sql .. ' WHERE ' .. toKeyValStr(id_or_cond)
  else
    sql = sql .. ' WHERE ' .. self.primary_key .. ' = ' .. toSqlVal(id_or_cond)
  end
  return self:exec(sql)
end

function M:where(...)
  return SQLChain.new(self):where(...)
end

function M:exec(sql)
  return self.db:exec(sql)

  -- local ok, r = xpcall(self.db.exec, function(err)
  --   Log.error_with_traceback(err)
  -- end, self.db, sql)
  -- if ok then
  --   return r
  -- end

  -- return self.db:execsql(sql)
end

function M:toRowTable(r)
  local t = {}
  for i, k in ipairs(r[0]) do
    t[k] = r[k][1]
  end
  return t
end

-- r: {
--  [0] = {'col_name1', 'col_name2'},
--  [1] = {'col1_val', 'col2_val'},
--  [2] = {'col1_val', 'col2_val'}
-- }
function M:toRowsTable(r)
  local rows = {}
  for i = 1, #r[1] do
    local t = {}
    for j, k in ipairs(r[0]) do t[k] = r[k][i] end
    table.insert(rows, t)
  end
  return rows
end

------------------

-- return: { k1_info, k2_info, ..., [k1] = info1, [k2] == info2 }, primary_key_name
function M._parse_table_info(table_raw_info)
  local r = {}
  local pkey
  for i, v in ipairs(table_raw_info.name) do
    local col_desc = {
      name = v,
      data_type = table_raw_info.type[i],
      pk = table_raw_info.pk[i] ~= 0,
      notnull = table_raw_info.notnull[i] ~= 0,
      dflt_value = table_raw_info.dflt_value[i], -- default value
    }
    r[#r + 1] = col_desc
    r[v] = col_desc
    if col_desc.pk then
      pkey = v
    end
  end
  return r, pkey
end

--[[
table_schema: string or table.
  "id INTEGER PRIMARY KEY, val INTEGER NOT NULL"
  or { { "id" "INTEGER" "PRIMARY KEY" }, { "val", "INTEGER", "NOT NULL" }, ... }
]]
function M:_create_table(table_name, table_schema)
  if type(table_schema) == 'table' then
    local cols = {}
    for i, desc in ipairs(table_schema) do
      cols[#cols + 1] = string.format("%s %s %s", desc[1], desc[2], desc[3] or '')
    end
    table_schema = table.concat(cols, ', ')
  end
  local table_init_sql = string.format(
    "CREATE TABLE IF NOT EXISTS %s(%s);", table_name, table_schema
  )
  self:exec(table_init_sql)
end

--[[
table_index:
  { { 'xxx_index', { 'col1', 'col2', ...' }, unique = true }, ... }
]]
function M:_create_table_index(table_name, table_index)
  for i, desc in ipairs(table_index) do
    local index_sql
    if type(desc) == 'string' then
      index_sql = desc
    else
      index_sql = string.format(
        "CREATE %s INDEX %s ON %s(%s);",
        desc.unique and 'UNIQUE' or '', desc[1], table_name, table.concat(desc[2], ', ')
      )
    end
    self:exec(index_sql)
  end
end

return M

