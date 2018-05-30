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
query = model:where{key = 'k'}:where("data like '1%'"):order('key desc'):limit(10)
query:select('key')

-- convert this query to sql
query:to_sql() -- SELECT key FROM xxx WHERE (key = 'k') AND (data like '1%') ORDER BY key desc LIMIT 10

-- execute query
query:to_a() -- {{key = xx}, {key = yy}}
query:to_a() -- it will query again
query:first() -- {key = xx}

query:reset()
query:to_sql() -- SELECT * FROM xxx
```

Format where condition, just gsub the '?' and convert the value to sql value. It doesn't escape dangerous input

```
model:where("item_type = ? AND width > ?", 'type1', 123)
-- eql
model:where("item_type = 'type1' AND width > 123", 'type1', 123)
```

More see `spec/model_spec.lua`


## TODO

* Fix the ';' bug for `lua-ljsqlite3`, if our text include ';' it will split the sql


## Development

If you want help this project, follow this flow

* Install `busted`
* Add your code
* Update the testing
* Run `bin/busted`, make sure the testing is pass
* Push your code and create a merge request
