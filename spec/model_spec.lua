describe("model", function()
  local model

  before_each(function()
    Model.conn = nil
    model = Model.new('test', [[
      CREATE TABLE IF NOT EXISTS test(key char(10) PRIMARY KEY, data TEXT, item_type CHAR(10));
    ]])
  end)

  describe("new", function()
    it("should save columns", function()
      assert.is_same(model.columns, {'key', 'data', 'item_type'})
    end)
  end)

  describe("create/find", function()
    it("should create data and find it", function()
      model:create({key = 'kk', data = 'vv', item_type = 'it'})
      local t = model:find('kk')
      assert.is_same(t, {key = 'kk', data = 'vv', item_type = 'it'})
    end)

    it("should create more data and find them", function()
      model:create({key = 'k1', data = 'vv', item_type = 'it'})
      model:create({key = 'k2', data = 'vv', item_type = 'it'})
      model:create({key = 'k3', data = 'vv', item_type = 'it'})
      assert.is_same(model:find('k3'), {key = 'k3', data = 'vv', item_type = 'it'})
      assert.is_same(model:find('k1'), {key = 'k1', data = 'vv', item_type = 'it'})
    end)

    it("should raise error if the primary key is the same", function()
      assert.has_error(function()
        model:create({key = 'kk', data = 'vv', item_type = 'it'})
        model:create({key = 'kk', data = 'vv', item_type = 'it'})
      end)
    end)

    it("should return nil if not found any", function()
      assert.is_same(model:find('asdf'), nil)
    end)

    it("should return id", function()
      model = Model.new('other', [[CREATE TABLE other(id INTEGER PRIMARY KEY, val TEXT)]])
      assert.is_same(model:create({val = 123}), 1)
      assert.is_same(model:create({val = 321}), 2)
      assert.is_same(model:create({val = 111}), 3)

      assert.is_same(model:find(1), {id = 1, val = '123'})
      assert.is_same(model:find(3), {id = 3, val = '111'})
      assert.is_same(model:find(2), {id = 2, val = '321'})
    end)
  end)

  describe("update", function()
    it("should update data", function()
      model:create({key = 'kk', data = 'vv', item_type = 'it'})
      model:update('kk', {data = '11'})
      assert.is_same(model:find('kk'), {key = 'kk', data = '11', item_type = 'it'})

      model:update({key = 'kk'}, {key = '123', data = '11', item_type = '321'})
      assert.is_same(model:find('key'), nil)
      assert.is_same(model:find('123'), {key = '123', data = '11', item_type = '321'})
    end)
  end)

  describe("delete", function()
    it('should delete record by primary key', function()
      model:create({key = 'kk', data = 'vv', item_type = 'it'})
      model:delete('kk')
      assert.is_same(model:find('kk'), nil)
    end)

    it('should delete record by cond', function()
      model:create({key = 'kk', data = 'vv', item_type = 'it'})
      model:delete({key = 'kk'})
      assert.is_same(model:find('kk'), nil)
    end)
  end)

  describe("where", function()
    it('should find by table cond', function()
      model:create({key = 'kk', data = 'vv', item_type = 'it'})
      model:create({key = 'jj', data = 'vv', item_type = 'it'})
      model:create({key = 'hh', data = '11', item_type = 'it'})
      assert.is_same(model:where({data = 'vv'}), {
        {key = 'kk', data = 'vv', item_type = 'it'},
        {key = 'jj', data = 'vv', item_type = 'it'}
      })
    end)

    it('should find by string cond', function()
      model:create({key = 'kk', data = 'vv', item_type = 'it'})
      model:create({key = 'jj', data = 'vv', item_type = 'it'})
      model:create({key = 'hh', data = '11', item_type = 'it'})
      assert.is_same(model:where("data = 'vv' OR key = 'hh'"), {
        {key = 'kk', data = 'vv', item_type = 'it'},
        {key = 'jj', data = 'vv', item_type = 'it'},
        {key = 'hh', data = '11', item_type = 'it'}
      })
    end)
  end)
end)
