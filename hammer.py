import psycopg2
import random
import time

try: range = xrange
except NameError: pass

conn = psycopg2.connect("")

with conn, conn.cursor() as cur:
	cur.execute("drop table if exists hammer")
	cur.execute("create table hammer (id serial primary key, count integer not null default 0)")
	for _ in range(100): cur.execute("insert into hammer default values")

print("Hammering PostgreSQL...")
start = time.time()
ok = 0
for _ in range(1000):
	with conn, conn.cursor() as cur:
		cur.execute("update hammer set count=count+1 where id=%s", (random.randrange(1,101),))
		ok += 1
tm = time.time() - start
with conn, conn.cursor() as cur:
	cur.execute("select sum(count) from hammer")
	done = cur.fetchone()[0]
	if done != ok:
		print("Something went wrong!")
		print("We thought that %d transactions happened, but %d did." % (ok, done))
		print("Statistics may be invalid.")

print("Completed %d transactions in %f seconds: %f tps" % (ok, tm, ok/tm))
with conn, conn.cursor() as cur:
	cur.execute("drop table if exists hammer")
