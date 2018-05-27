Lua SQL Model
=============

Help you easily to read/write SQLite3 data.


## Usage

```
model = Model.new('test', [[
  CREATE TABLE IF NOT EXISTS test(key char(10) PRIMARY KEY, data TEXT);
]]);

model.create({key = 'k', data = '123'})
model.find('k') -- {key = 'k', data = '123'}
model.where({data = '123'}) -- {{key = 'k', data = '123'}}
model.where("data = '123'") -- {{key = 'k', data = '123'}}

model.update('k', {data = '321'}) 
model.find('k') -- {key = 'k', data = '321'}
model.update("data = 321 AND key = 'k'", {key = '1', data = '11'}) 
model.find('1') -- {key = '1', data = '11'}

model.delete('1')
model.find('1') -- nil
```

More see `spec/model_spec.lua`

