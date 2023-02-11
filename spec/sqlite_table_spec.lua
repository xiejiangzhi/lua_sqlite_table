describe("sqlite_table", function()
  local table

  before_each(function()
    table = SqliteTable.new(nil, 'test', {
      { 'key', 'char(10)', 'PRIMARY KEY NOT NULL' },
      { 'data', 'TEXT' },
      { 'item_type', 'CHAR(10)' }
    }, {
      { "data_index", { 'data', } },
      { "item_data_index", { 'item_type', 'data' } }
    })
  end)

  describe("new", function()
    it("should create columns", function()
      local table_info = {
        {
          data_type = "char(10)",
          name = "key",
          notnull = true,
          pk = true
        },
        {
          data_type = "TEXT",
          name = "data",
          notnull = false,
          pk = false
        },
        {
          data_type = "CHAR(10)",
          name = "item_type",
          notnull = false,
          pk = false
        },
      }
      table_info.key = table_info[1]
      table_info.data = table_info[2]
      table_info.item_type = table_info[3]
      assert.is_same(table.table_info, table_info)
    end)

    it("should create indexes", function()
      local table2 = SqliteTable.new(nil, 'test_t2', {
        { 'key', 'char(10)', 'PRIMARY KEY' },
        { 'data', 'TEXT' },
        { 'item_type', 'CHAR(10)' }
      }, {
        { "data_index", { 'data', } },
        { "item_data_index", { 'item_type', 'data' }, unique = true }
      })
      local res = table2:exec("PRAGMA index_list('test_t2')")
      assert.is_same(res.name, { 'item_data_index', 'data_index', 'sqlite_autoindex_test_t2_1' })
      assert.is_same(res.unique, { 1, 0, 1 })
    end)
  end)

  describe("create/find", function()
    it("should create data and find it", function()
      table:create({key = 'kk', data = 'vv', item_type = 'it'})
      local t = table:find('kk')
      assert.is_same(t, {key = 'kk', data = 'vv', item_type = 'it'})
    end)

    it("should create more data and find them", function()
      table:create({key = 'k1', data = 'vv', item_type = 'it'})
      table:create({key = 'k2', data = 'vv', item_type = 'it'})
      table:create({key = 'k3', data = 'vv', item_type = 'it'})
      assert.is_same(table:find('k3'), {key = 'k3', data = 'vv', item_type = 'it'})
      assert.is_same(table:find('k1'), {key = 'k1', data = 'vv', item_type = 'it'})
    end)

    it("should raise error if the primary key is the same", function()
      assert.has_error(function()
        table:create({key = 'kk', data = 'vv', item_type = 'it'})
        table:create({key = 'kk', data = 'vv', item_type = 'it'})
      end)
    end)

    it("should return nil if not found any", function()
      assert.is_same(table:find('asdf'), nil)
    end)

    it("should return id", function()
      table = SqliteTable.new(nil, 'other', "id INTEGER PRIMARY KEY, val TEXT")
      assert.is_same(table:create({val = 123}), 1)
      assert.is_same(table:create({val = 321}), 2)
      assert.is_same(table:create({val = 111}), 3)

      assert.is_same(table:find(1), {id = 1, val = '123'})
      assert.is_same(table:find(3), {id = 3, val = '111'})
      assert.is_same(table:find(2), {id = 2, val = '321'})
    end)

    it('should escape quote', function()
      table:create({key = 'k\'1', data = "v%?123v'\""})
      assert.is_same(table:find('k\'1'), {key = "k'1", data = "v%?123v'\"", item_type = nil})
    end)

    it('should escape ;', function()
      table:create({key = 'k\'1', data = "v%?;123v'\""})
      assert.is_same(table:find('k\'1'), {key = "k'1", data = "v%?;123v'\"", item_type = nil})
    end)
  end)

  describe("update", function()
    it("should update data", function()
      table:create({key = 'kk', data = 'vv', item_type = 'it'})
      table:update('kk', {data = '11'})
      assert.is_same(table:find('kk'), {key = 'kk', data = '11', item_type = 'it'})

      table:update({key = 'kk'}, {key = '123', data = '11', item_type = '321'})
      assert.is_same(table:find('key'), nil)
      assert.is_same(table:find('123'), {key = '123', data = '11', item_type = '321'})
    end)

    it("should escape quote", function()
      table:create({key = 'k\'k', data = 'vv', item_type = 'it'})
      table:update('k\'k', {data = '1\'"1'})
      assert.is_same(table:find('k\'k'), {key = 'k\'k', data = '1\'"1', item_type = 'it'})
    end)
  end)

  describe("delete", function()
    it('should delete record by primary key', function()
      table:create({key = 'kk', data = 'vv', item_type = 'it'})
      table:delete('kk')
      assert.is_same(table:find('kk'), nil)
    end)

    it('should delete record by cond', function()
      table:create({key = 'kk', data = 'vv', item_type = 'it'})
      table:delete({key = 'kk'})
      assert.is_same(table:find('kk'), nil)
    end)

    it('should escape quote', function()
      table:create({key = 'k\'"k', data = 'vv', item_type = 'it'})
      table:delete({key = 'k\'"k'})
      assert.is_same(table:find('k\'"k'), nil)
    end)
  end)

  describe("where", function()
    it('should find by table cond', function()
      table:create({key = 'kk', data = 'vv', item_type = 'it'})
      table:create({key = 'jj', data = 'vv', item_type = 'it'})
      table:create({key = 'hh', data = '11', item_type = 'it'})
      assert.is_same(table:where({data = 'vv'}):to_a(), {
        {key = 'kk', data = 'vv', item_type = 'it'},
        {key = 'jj', data = 'vv', item_type = 'it'}
      })
    end)

    it('should find by string cond', function()
      table:create({key = 'kk', data = 'vv', item_type = 'it'})
      table:create({key = 'jj', data = 'vv', item_type = 'it'})
      table:create({key = 'hh', data = '11', item_type = 'it'})
      assert.is_same(table:where("data = 'vv' OR key = 'hh'"):to_a(), {
        {key = 'kk', data = 'vv', item_type = 'it'},
        {key = 'jj', data = 'vv', item_type = 'it'},
        {key = 'hh', data = '11', item_type = 'it'}
      })
    end)

    it('should escape quote', function()
      table:create({key = 'kk', data = 'v\'"v', item_type = 'it'})
      assert.is_same(table:where("data = 'v''\"v' OR key = 'hh'"):to_a(), {
        {key = 'kk', data = 'v\'"v', item_type = 'it'},
      })
    end)
  end)

  describe("sql chain", function()
    local query

    before_each(function()
      table:create({key = 'k1', data = 'vv', item_type = 'it'})
      table:create({key = 'k2', data = 'vv', item_type = 'it'})
      table:create({key = 'k3', data = '11', item_type = 'it'})
      table:create({key = 'k4', data = '11', item_type = 'it'})

      query = table:where('1 = 1')
      query:reset()
    end)

    it('should return all matched rows', function()
      assert.is_same(query:where({data = 11}):to_a(), {
        {key = 'k3', data = '11', item_type = 'it'},
        {key = 'k4', data = '11', item_type = 'it'}
      })
    end)

    it('reset should reset all options', function()
      query:where({data = 11}):order('key desc'):limit(1):select('key')

      assert.is_same(query:to_sql(), "SELECT key FROM test WHERE (data = 11) ORDER BY key desc LIMIT 1")
      query:reset()
      assert.is_same(query:to_sql(), "SELECT * FROM test")
    end)

    it('should format condition', function()
      assert.is_same(query:where("data = ? AND other = ?", 'str', 123):to_sql(),
        "SELECT * FROM test WHERE (data = 'str' AND other = 123)"
      )
      query:reset()

      assert.is_same(query:where("key = ?", 'k3'):to_a(), {
        {key = 'k3', data = '11', item_type = 'it'}
      })
    end)

    it("first should return the first one", function()
      assert.is_same(query:first(), {key = 'k1', data = 'vv', item_type = 'it'})
      assert.is_same(query:where({data = 11}):first(), {key = 'k3', data = '11', item_type = 'it'})
    end)

    it('should support limit', function()
      assert.is_same(query:where({data = 11}):limit(1):to_a(), {
        {key = 'k3', data = '11', item_type = 'it'}
      })
    end)

    it('should support order', function()
      assert.is_same(query:where({data = 11}):order('key desc'):to_a(), {
        {key = 'k4', data = '11', item_type = 'it'},
        {key = 'k3', data = '11', item_type = 'it'}
      })
    end)

    it('should support order', function()
      assert.is_same(query:where({data = 11}):order('key desc'):to_a(), {
        {key = 'k4', data = '11', item_type = 'it'},
        {key = 'k3', data = '11', item_type = 'it'}
      })
    end)

    it('should support select', function()
      assert.is_same(query:where({data = 11}):select('key, data'):to_a(), {
        {key = 'k3', data = '11'}, {key = 'k4', data = '11'}
      })
    end)

    it('should support count', function()
      assert.is_same(query:count(), 4)
      assert.is_same(query:where({data = 11}):count(), 2)
    end)

    it('should return data when use misc query', function()
      assert.is_same(query:where({data = 11}):order('key desc'):limit(1):select('key'):to_a(), {{key = 'k4'}})

      query:reset()
      -- multiple mixed where
      assert.is_same(
        query:where({data = 11}):where('data = 11'):order('key desc'):limit(1):select('key'):to_a(),
        {{key = 'k4'}}
      )

      query:reset()
      -- Not found anything
      assert.is_same(
        query:where({data = 11}):where('data = 123123123'):order('key desc'):limit(1):select('key'):to_a(),
        {}
      )
    end)
  end)
end)
