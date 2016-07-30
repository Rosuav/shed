constant TRANS=1000, FIELD=1000, EDITS=1, PROCESSES=2;
int main(int argc,array(string) argv)
{
	object sql=Sql.Sql("pgsql://rosuav:esstu@localhost/rosuav");
	if (argc == 1)
	{
		sql->query("drop table if exists throughput");
		sql->query("create table throughput (id serial primary key, payload int not null)");
		for (int i=0;i<FIELD;++i) sql->query("insert into throughput (payload) values (0)");
		sql->query("commit");
		write("Field initialized.\n");
		array proc = ({Process.create_process}) * PROCESSES;
		System.Timer tm = System.Timer();
		proc = proc(({"pike", argv[0], "run"}));
		proc->wait();
		float t = tm->peek();
		write("Time taken: %f\n", t);
		write("Approx TPS: %f\n", TRANS/t);
		write("Total increments done: %s\n", sql->query("select sum(payload) from throughput")[0]->sum);
		return 0;
	}
	//Subprocess: Run the whole job.
	write("Starting pid %d\n", getpid());
	for (int i=0; i<TRANS; ++i)
	{
		for (int j=0; j<EDITS; ++j)
		{
			int id = random(FIELD)+1;
			sql->query("update throughput set payload=payload+1 where id=%d", id);
		}
		sql->query("commit");
	}
	write("Finishing pid %d\n", getpid());
}
