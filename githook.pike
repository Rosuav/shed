#!/usr/bin/env pike
/* Multi-purpose git hook

Run this script from your top-level git directory and it'll install itself. Then,
it provides two services:

1) One-file commits can be tagged to show what file/module they're working on.
TODO: More explanation, thanks!

2) Short-hand fixup: edit a single file and create a commit with a message of
"f" (eg "git commit -amf") and the message will be expanded to "fixup!" and the
most recent unpushed commit message that affects this file. Good with git's
interactive rebase.
*/

int main(int argc,array(string) argv)
{
	string cmd=explode_path(argv[0])[-1];
	switch (cmd)
	{
		case "githook.pike":
			System.symlink(argv[0],".git/hooks/prepare-commit-msg");
			System.symlink(argv[0],".git/hooks/commit-msg");
			write("Installed.\n");
			break;
		case "prepare-commit-msg":
		{
			//For single-file commits, provide a prefix.
			//If the commit message doesn't start with a comment, don't touch it - it's probably a rebase.
			string msg=Stdio.File(argv[1])->read();
			if (argc<4 && has_prefix(String.trim_all_whites(msg),"#"))
			{
				array(string) stat=Process.run("git diff --cached --stat")->stdout/"\n";
				if (sizeof(stat)>1 && has_prefix(stat[1]-"s"," 1 file changed") && sscanf(stat[0]," %s |",string fn) && fn && fn!="") //One-file commits have a summary on line 2.
				{
					//To speed up the search:
					//$ git config rosuav.log-search.limit N
					//where N is some number of commits. This will cause failure if this branch of
					//this repo has not had that many commits yet (or to be more precise, if HEAD
					//doesn't have that many {grand,}parents).
					array(string) args=({"git","log","--shortstat","--full-diff","-10","--oneline"});
					int limit=(int)Process.run(({"git","config","--get","rosuav.log-search.limit"}))->stdout;
					if (limit) args+=({"HEAD~"+limit+".."});
					array(string) log=Process.run(args+({fn}))->stdout/"\n";
					mapping(string:int) tagcnt=([]);
					for (int i=0;i<sizeof(log)-1;i+=2) //log should be pairs of lines: ({commit + summary, shortstat}) repeated.
						if (has_prefix(log[i+1]," 1 file changed")) //Ignore commits that changed any other file
							if (sscanf(log[i],"%*s %s: %s",string tag,string msg) && msg) tagcnt[String.trim_all_whites(tag-"squash!"-"fixup!")]++;
					switch (sizeof(tagcnt))
					{
						case 0: break; //No tags found, nothing to do.
						case 1: Stdio.write_file(argv[1],indices(tagcnt)[0]+": \n"+msg); break;
						default:
						{
							array(string) tags=indices(tagcnt); sort(values(tagcnt),tags); //Sort by count (ascending)
							foreach (tags,string tag) msg="# "+tag+": \n"+msg; //Prepend each one, thus having them in the message in descending order
							Stdio.write_file(argv[1],msg);
						}
					}
				}
			}
			break;
		}
		case "commit-msg":
		{
			//Short-hand fixup: apply the fixup to the most recent commit that touched this file.
			//Instead of "git commit filename --fixup=12ab34", use "git commit filename -mf" and the fixup will be applied to the
			//most recent unpushed commit that affected the file you're committing. Done only if a single-file commit, for safety.
			//Designed for "git rebase -i" with option rebase.autosquash=true; effectively allows casual amending of commits
			//other than the current branch head. In the common case where nothing else is changed: "git commit -amf"
			string msg=Stdio.File(argv[1])->read();
			if (String.trim_all_whites(msg)=="f")
			{
				array(string) stat=Process.run("git diff --cached --stat")->stdout/"\n";
				if (sizeof(stat)>1 && has_prefix(stat[1]," 1 file changed") && sscanf(stat[0]," %s |",string fn) && fn && fn!="") //As above
				{
					//Bound the search to unpushed changes only.
					string branch=String.trim_all_whites(Process.run(({"git","symbolic-ref","--short","-q","HEAD"}))->stdout);
					if (branch=="") exit(1,"Shortcut fixup commits work only on a branch.\n");
					array(string) log=Process.run(({"git","log","origin/"+branch+"..","--shortstat","--full-diff","-1","--oneline",fn}))->stdout/"\n";
					if (sizeof(log)>1)
					{
						sscanf(log[0],"%*s %s",string msg);
						sscanf(msg,"fixup! %s",msg); //Don't double-head the markers
						Stdio.write_file(argv[1],"fixup! "+msg);
					}
				}
			}
			break;
		}
		default: exit(1,"This script does not handle a %s hook.\n",cmd);
	}
}
