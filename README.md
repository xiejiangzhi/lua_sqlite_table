Lua SQL Model
=============

Help you easily to read/write SQLite3 data.

It is based on [lua-ljsqlite3](https://github.com/stepelu/lua-ljsqlite3)


## Usage

```
model = Model.new('test', [[
  CREATE TABLE IF NOT EXISTS test(key char(10) PRIMARY KEY, data TEXT);
]]);

model:create({key = 'k', data = '123'})
model:find('k') -- {key = 'k', data = '123'}
model:where({data = '123'}):to_a() -- {{key = 'k', data = '123'}}
model:where("data = '123'"):to_a() -- {{key = 'k', data = '123'}}

model:update('k', {data = '321'})
model:find('k') -- {key = 'k', data = '321'}
model:update("data = 321 AND key = 'k'", {key = '1', data = '11'}) 
model:find('1') -- {key = '1', data = '11'}

model:delete('1')
model:find('1') -- nil

model:exec('select * from test')
```

Query Chain

```
query = model:where{key = 'k'}:where("data like "1%"):order('key desc'):limit(10)
query:select('key')

-- execute query
query:to_a() -- {{key = xx}, {key = yy}}
query:to_a() -- it will query again
query:first() -- {key = xx}
```

More see `spec/model_spec.lua`

