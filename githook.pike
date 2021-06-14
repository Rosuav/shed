#!/usr/bin/env pike
/* Multi-purpose git hook

Run this script from your top-level git directory and it'll install itself. Then,
it provides two services:

1) One-file commits can be tagged to show what file/module they're working on.
The first time you do such a commit, identify the file with a tag, followed by
a colon - for example, "githook: New script" - and then all subsequent commits
for that file will have the "githook:" part prefilled. (Note that this doesn't
work with 'git gui', which appears to skip the prepare-commit-msg hook.) Having
multiple files with the same tag allows them all to be part of a conceptual
module, although the hook won't recognize any multi-file commits, even if the
files would all have used the same tag separately.

NOTE: This search can take a long time; it scans backward through potentially
the entire history of this branch of the repository. To bound the search to N
commits back from the current HEAD:
$ git config rosuav.log-search.limit N
This can be set globally or per-repository. If the bound is set too low, files
which have not been edited in a long time may not be detected as having tags
set, and will be treated as brand new again.

2) Short-hand fixup: edit a single file and create a commit with a message of
"f" (eg "git commit -amf") and the message will be expanded to "fixup!" and the
most recent unpushed commit message that affects this file. Good with git's
interactive rebase, especially with git config rebase.autosquash enabled.
*/

int main(int argc,array(string) argv)
{
	string cmd=explode_path(argv[0])[-1];
	if (cmd == "githook.pike")
	{
		foreach (indices(this), string fn)
			if (sscanf(fn, "hook_%s", string hook))
				System.symlink(argv[0], ".git/hooks/" + replace(hook, "_", "-"));
		write("Installed.\n");
	}
	else if (function f = this["hook_" + replace(cmd, "-", "_")])
		return f(argv);
	else exit(1,"This script does not handle a %s hook.\n",cmd);
}

int hook_prepare_commit_msg(array(string) argv)
{
	//For single-file commits, provide a prefix.
	//If the commit message doesn't start with a comment, don't touch it - it's probably a rebase.
	string msg=Stdio.File(argv[1])->read();
	if (sizeof(argv)<4 && has_prefix(String.trim_all_whites(msg),"#"))
	{
		//NOTE: The diff shows paths relative to the repository root, but 'git log' below works with
		//paths relative to the current directory. When this is run as a git hook, the cwd always
		//appears to be the repo root, but I don't know that this is guaranteed. I can't find it in
		//the docs anywhere, for instance; but it does seem likely and logical.
		array(string) stat=Process.run("git diff --cached --stat")->stdout/"\n";
		if (sizeof(stat)>1 && has_prefix(stat[1]-"s"," 1 file changed") && sscanf(stat[0]," %s |",string fn) && fn && fn!="") //One-file commits have a summary on line 2.
		{
			//Hack for CJAPrivate repo
			if (int use_hacks=(int)Process.run(({"git","config","--get","rosuav.log-search.use-hacks"}))->stdout)
			{
				//Thinkful invoices usually get simple additions of single lines.
				if (has_prefix(fn,"Thinkful/Inv"))
				{
					string comment;
					foreach (Process.run(({"git","diff","-U0","--cached"}))->stdout/"\n",string line)
					{
						if (sscanf(line,"+| %*d\t| %s%*[\t]| %f\t| %f", string c, float hours, float dollars) == 5)
						{
							if (hours * use_hacks != dollars)
								exit(1,"%O hours doesn't match %O dollars - maybe tweak the hook for flexibility?\n", hours, dollars);
							comment=c;
						}
					}
					if (comment) {Stdio.write_file(argv[1],comment+"\n"+msg); return 0;}
				}
			}
			//To speed up the search on large repositories:
			//$ git config rosuav.log-search.limit N
			//where N is some number of commits. This will cause failure if this branch of
			//this repo has not had that many commits yet (or to be more precise, if HEAD
			//doesn't have that many {grand,}parents).
			array(string) args=({"git","log","--shortstat","--full-diff","-10","--oneline"});
			array(string) log;
			if (int limit=(int)Process.run(({"git","config","--get","rosuav.log-search.limit"}))->stdout)
			{
				mapping rc=Process.run(args+({"HEAD~"+limit+"..",fn}));
				if (!rc->exitcode) log=rc->stdout/"\n";
				//If this fails, try again without the limit.
			}
			if (!log) log=Process.run(args+({fn}))->stdout/"\n"; //If this one fails, though, just work with no lines (ie no tags).
			mapping(string:int) tagcnt=([]);
			for (int i=0;i<sizeof(log)-1;i+=2) //log should be pairs of lines: ({commit + summary, shortstat}) repeated.
				if (has_prefix(log[i+1]-"s"," 1 file changed")) //Ignore commits that changed any other file
					if (sscanf(log[i],"%*s %s: %s",string tag,string msg) && msg) tagcnt[String.trim_all_whites(tag-"squash!"-"fixup!"-"Revert \"")]++;
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
}

int hook_commit_msg(array(string) argv)
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
		if (sizeof(stat)>1 && has_prefix(stat[1]-"s"," 1 file changed") && sscanf(stat[0]," %s |",string fn) && fn && fn!="") //As above
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
}
