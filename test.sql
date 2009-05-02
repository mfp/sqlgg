-- [sql2cpp] name=create
CREATE TABLE test (id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT,descr TEXT);
-- [sql2cpp] name=select_all
SELECT * FROM test;
SELECT name,descr FROM test;
INSERT INTO test VALUES;
-- [sql2cpp] name=Add
INSERT INTO test (name,descr) VALUES;
SELECT * FROM test WHERE name = @name LIMIT @limit;
-- [sql2cpp] name=select_distinct_limit
SELECT DISTINCT * 
FROM test ORDER BY id DESC LIMIT ?;
-- [sql2cpp] name=Delete
DELETE FROM test WHERE id = ?;
-- [sql2cpp] name=Exaggerate
UPDATE test SET descr = @extra || ' ' || descr;

CREATE TABLE loc (id INTEGER PRIMARY KEY AUTOINCREMENT, city TEXT, test_id INTEGER);
SELECT test.id FROM test JOIN loc ON test_id = id;
SELECT test.id FROM test WHERE id = ? UNION SELECT test.id FROM test WHERE id = ?;
SELECT id+test_id AS x,? FROM loc ORDER BY id,?/test_id LIMIT ?,100;
SELECT x,z FROM (SELECT name AS x, 
  city || ' ' || descr as y, 
  max(length(city),random(*)) as z FROM test LEFT JOIN loc) WHERE x > @xlo AND z < @zhi;

-- FIXME id is ambigous, should be detected
CREATE TABLE zuzu AS SELECT test.id,@text || city AS city, name FROM loc JOIN test ON test_id=id;

